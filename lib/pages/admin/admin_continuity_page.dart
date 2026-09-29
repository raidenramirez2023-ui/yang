import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/admin_continuity_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/models/audit_log_model.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/global_messenger.dart';

class AdminContinuityPage extends StatefulWidget {
  const AdminContinuityPage({super.key});

  @override
  State<AdminContinuityPage> createState() => _AdminContinuityPageState();
}

class _AdminContinuityPageState extends State<AdminContinuityPage>
    with SingleTickerProviderStateMixin {
  // Brand color palette
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _emerald = Color(0xFF14332E);
  static const Color _gold = Color(0xFFD9A441);
  static const Color _goldDark = Color(0xFFC9922E);
  static const Color _slate = Color(0xFF64748B);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _successGreen = Color(0xFF16A34A);

  late TabController _tabController;
  AdminContinuityConfig? _config;
  bool _isLoading = true;
  List<AuditLog> _continuityAuditLogs = [];
  List<Map<String, dynamic>> _formalContinuityRecords = [];
  int _selectedAuditView = 0;
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final config = await AdminContinuityService.getConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
      }
      _loadAuditLogs();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        GlobalMessenger.showError("Failed to load continuity data: $e");
      }
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final logs = await AuditLogService.fetchLogs(
        module: 'Admin Governance',
        limit: 50,
      );
      final records = await AdminContinuityService.getContinuityRecords(limit: 50);
      if (mounted) {
        setState(() {
          _continuityAuditLogs = logs;
          _formalContinuityRecords = records;
          _isLoadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: _emerald),
        ),
      );
    }

    final config = _config ?? AdminContinuityConfig.defaultInitial();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 14 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context, config),
            const SizedBox(height: 16),
            _buildContinuityHealthBanner(config),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 20),
            SizedBox(
              height: isMobile ? 850 : 750,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAccountsTab(config),
                  _buildSuccessionTab(config),
                  _buildAuditTrailTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header & Top Banners ───────────────────────────────────────────────

  Widget _buildPageHeader(BuildContext context, AdminContinuityConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.security_rounded, color: _gold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Admin Continuity & Recovery',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: isMobile ? 16 : 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: config.isSuccessionCompleted
                            ? _dangerRed.withValues(alpha: 0.2)
                            : _successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: config.isSuccessionCompleted
                              ? _dangerRed.withValues(alpha: 0.5)
                              : _successGreen.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        config.isSuccessionCompleted
                            ? 'SUCCESSION ACTIVE'
                            : 'CONTINUITY PROTECTED',
                        style: GoogleFonts.inter(
                          color: config.isSuccessionCompleted ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Enterprise-grade governance, secondary administrator redundancy, and emergency administrative succession protocol.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            OutlinedButton.icon(
              onPressed: _showResetToBaselineDialog,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Demo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinuityHealthBanner(AdminContinuityConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hasBackup = config.hasBackupAssigned;
    final isCoAdmin = config.isCoAdminAuthorized;

    final bannerContent = RichText(
      text: TextSpan(
        style: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: isMobile ? 12 : 13),
        children: [
          TextSpan(
            text: hasBackup
                ? 'Continuity Status: 100% Operational. '
                : 'Continuity Advisory: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: hasBackup
                ? (isCoAdmin
                    ? 'Primary Admin (${config.primaryAdminEmail}) has authorized backup administrator (${config.backupAdminEmail}) as Active Co-Administrator.'
                    : 'Primary Admin (${config.primaryAdminEmail}) has designated backup administrator (${config.backupAdminEmail}) on Standby (Emergency Recovery only; login locked).')
                : 'No Authorized Backup Administrator assigned. Designate a backup admin to guarantee business continuity.',
          ),
        ],
      ),
    );

    final nistBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'NIST SP 800-63 Compliant',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _slate,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hasBackup ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: hasBackup ? _successGreen : _goldDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: bannerContent),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: nistBadge,
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  hasBackup ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: hasBackup ? _successGreen : _goldDark,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: bannerContent),
                const SizedBox(width: 12),
                nistBadge,
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: isMobile,
        tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
        labelColor: _emerald,
        unselectedLabelColor: _slate,
        indicatorColor: _gold,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: isMobile ? 12 : 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 13),
        tabs: const [
          Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Admin Accounts'),
          Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Emergency Succession'),
          Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Audit Trail'),
        ],
      ),
    );
  }

  // ─── Tab 1: Admin Accounts ───────────────────────────────────────────────

  Widget _buildAccountsTab(AdminContinuityConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Administrative Account Hierarchy',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showUpdateSecurityKeyDialog(config),
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text(isMobile ? 'Change Security Key' : 'Change Security Verification Key'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _emerald,
                  side: const BorderSide(color: _emerald),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[
            _buildPrimaryAdminCard(config),
            const SizedBox(height: 16),
            _buildBackupAdminCard(config),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPrimaryAdminCard(config)),
                const SizedBox(width: 16),
                Expanded(child: _buildBackupAdminCard(config)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _buildAccountPolicyGuidelines(),
        ],
      ),
    );
  }

  Widget _buildPrimaryAdminCard(AdminContinuityConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: _emerald, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Primary Administrator',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Primary account holder with operational and governance authority.',
                      style: GoogleFonts.inter(fontSize: 11, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _buildInfoRow(Icons.person_outline, 'Full Name', config.primaryAdminName),
          _buildInfoRow(Icons.email_outlined, 'Named Email', config.primaryAdminEmail),
          _buildInfoRow(Icons.badge_outlined, 'Official Title', config.primaryAdminTitle),
          _buildInfoRow(Icons.phone_outlined, 'Contact Hotline', config.primaryAdminPhone),
          _buildInfoRow(Icons.shield_outlined, 'Identity Rule', 'Individual Account (No Shared Passwords)'),
          const SizedBox(height: 16),
          if (isMobile) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUpdatePrimaryDialog(config),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit Details', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _emerald,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangeEmailDialog(config.primaryAdminEmail, config.primaryAdminName),
                    icon: const Icon(Icons.alternate_email_rounded, size: 14),
                    label: const Text('Change Email', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      backgroundColor: const Color(0xFFF0F9FF),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showChangePasswordDialog(config.primaryAdminEmail, config.primaryAdminName),
                icon: const Icon(Icons.lock_reset_rounded, size: 14),
                label: const Text('Change Password', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUpdatePrimaryDialog(config),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _emerald,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangeEmailDialog(config.primaryAdminEmail, config.primaryAdminName),
                    icon: const Icon(Icons.alternate_email_rounded, size: 15),
                    label: const Text('Change Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      backgroundColor: const Color(0xFFF0F9FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showChangePasswordDialog(config.primaryAdminEmail, config.primaryAdminName),
                    icon: const Icon(Icons.lock_reset_rounded, size: 15),
                    label: const Text('Change Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackupAdminCard(AdminContinuityConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hasBackup = config.hasBackupAssigned;
    final isCoAdmin = config.isCoAdminAuthorized;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBackup ? const Color(0xFFE2E8F0) : _gold.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCoAdmin
                      ? _emerald.withValues(alpha: 0.12)
                      : _gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCoAdmin ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded,
                  color: isCoAdmin ? _emerald : _goldDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Authorized Backup Admin',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: !hasBackup
                                ? const Color(0xFFFEE2E2)
                                : (isCoAdmin
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: !hasBackup
                                  ? const Color(0xFFFCA5A5)
                                  : (isCoAdmin
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFDE68A)),
                            ),
                          ),
                          child: Text(
                            !hasBackup
                                ? 'UNASSIGNED'
                                : (isCoAdmin ? 'AUTHORIZED CO-ADMIN' : 'STANDBY (LOCKED)'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: !hasBackup
                                  ? _dangerRed
                                  : (isCoAdmin ? _emerald : _goldDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCoAdmin
                          ? 'Authorized by Primary Admin to access the Admin Portal for daily operations.'
                          : 'Designated successor on standby. Normal login locked until authorized or emergency succession.',
                      style: GoogleFonts.inter(fontSize: 11, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          if (hasBackup) ...[
            _buildInfoRow(Icons.person_outline, 'Full Name', config.backupAdminName),
            _buildInfoRow(Icons.email_outlined, 'Named Email', config.backupAdminEmail),
            _buildInfoRow(Icons.badge_outlined, 'Official Title', config.backupAdminTitle),
            _buildInfoRow(Icons.phone_outlined, 'Contact Hotline', config.backupAdminPhone),
            _buildInfoRow(Icons.lock_clock_outlined, 'Credentials', 'Separate Unique Login & Password'),
            _buildInfoRow(
              isCoAdmin ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              'Login Authority',
              isCoAdmin
                  ? 'Authorized — Normal Staff Login Permitted'
                  : 'Locked in Standby — Normal Staff Login Blocked',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'No backup administrator is currently designated. In an unexpected emergency, operational continuity will be at risk.',
                style: GoogleFonts.inter(color: const Color(0xFF92400E), fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (hasBackup) ...[
            Row(
              children: [
                Expanded(
                  child: isCoAdmin
                      ? OutlinedButton.icon(
                          onPressed: () => _showConfirmToggleAuthorityDialog(config, 'standby'),
                          icon: const Icon(Icons.lock_clock_rounded, size: 14),
                          label: Text(
                            isMobile ? 'Revoke' : 'Revoke to Standby',
                            style: TextStyle(fontSize: isMobile ? 12 : 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _showConfirmToggleAuthorityDialog(config, 'co_admin'),
                          icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                          label: Text(
                            isMobile ? 'Authorize Login' : 'Authorize Co-Admin Login',
                            style: TextStyle(fontSize: isMobile ? 12 : 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _emerald,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAssignBackupDialog(config),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(
                      isMobile ? 'Update Backup' : 'Update Backup Admin',
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangeEmailDialog(config.backupAdminEmail, config.backupAdminName),
                    icon: const Icon(Icons.alternate_email_rounded, size: 14),
                    label: Text('Change Email', style: TextStyle(fontSize: isMobile ? 12 : 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      backgroundColor: const Color(0xFFF0F9FF),
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangePasswordDialog(config.backupAdminEmail, config.backupAdminName),
                    icon: const Icon(Icons.lock_reset_rounded, size: 14),
                    label: Text('Change Password', style: TextStyle(fontSize: isMobile ? 12 : 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _emerald,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAssignBackupDialog(config),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Designate Backup Administrator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _slate),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _slate,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountPolicyGuidelines() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Principle: Separation of Individual Accounts',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• The Primary Administrator and Backup Administrator each have their OWN named email and password.\n'
            '• Credentials must NEVER be shared between individuals or written on physical notes.\n'
            '• If the Primary Administrator becomes permanently unavailable, the Backup Administrator transitions to primary using their OWN account.\n'
            '• Historical records created by the previous administrator are permanently preserved and remain tied to their name in the audit trail.',
            style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: const Color(0xFF14532D)),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Emergency Succession ────────────────────────────────────────

  Widget _buildSuccessionTab(AdminContinuityConfig config) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSuccessionStepper(),
          const SizedBox(height: 24),
          if (config.isSuccessionCompleted)
            _buildSuccessionCompletedCertificate(config)
          else
            _buildSuccessionActionCard(config),
        ],
      ),
    );
  }

  Widget _buildSuccessionStepper() {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Standard Operating Succession Flow',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[
            _buildStepItemMobile('1', 'Incident Occurs', 'Primary Admin permanently unavailable (accident / death / incapacitation)', isLast: false),
            _buildStepItemMobile('2', 'Initiate Recovery', 'Authorized Backup Admin / Management files succession request', isLast: false),
            _buildStepItemMobile('3', 'Verify Authority', 'Verification Key & reference document validated', isLast: false),
            _buildStepItemMobile('4', 'Access Transfer', 'Backup Admin becomes Primary; Old admin account deactivated', isLast: false),
            _buildStepItemMobile('5', 'Audit Logged', 'Immutable record saved; business operations continue uninterrupted', isLast: true),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepItem('1', 'Incident Occurs', 'Primary Admin permanently unavailable (accident / death / incapacitation)'),
                const Icon(Icons.arrow_forward_rounded, color: _slate, size: 16),
                _buildStepItem('2', 'Initiate Recovery', 'Authorized Backup Admin / Management files succession request'),
                const Icon(Icons.arrow_forward_rounded, color: _slate, size: 16),
                _buildStepItem('3', 'Verify Authority', 'Verification Key & reference document validated'),
                const Icon(Icons.arrow_forward_rounded, color: _slate, size: 16),
                _buildStepItem('4', 'Access Transfer', 'Backup Admin becomes Primary; Old admin account deactivated'),
                const Icon(Icons.arrow_forward_rounded, color: _slate, size: 16),
                _buildStepItem('5', 'Audit Logged', 'Immutable record saved; business operations continue uninterrupted'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItemMobile(String number, String title, String description, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: _emerald,
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(fontSize: 10.5, color: _slate),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String description) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _emerald,
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 9, color: _slate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessionActionCard(AdminContinuityConfig config) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Administrative Succession Trigger',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Execute only in the event of confirmed, permanent unavailability of the Primary Administrator.',
                      style: GoogleFonts.inter(fontSize: 12, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            'Requirements for Execution:\n'
            '1. Authorized Backup Administrator must be assigned and verified.\n'
            '2. Requester must provide an Official Reference Document Number (e.g., HR incident memo, death certificate, board resolution).\n'
            '3. System Continuity Security Verification Key must be entered.\n'
            '4. Former administrator\'s account credentials will be immediately deactivated to prevent rogue access.\n'
            '5. An immutable audit log entry will be permanently written.',
            style: GoogleFonts.inter(fontSize: 12, height: 1.6, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: config.hasBackupAssigned
                ? () => _showInitiateSuccessionDialog(config)
                : null,
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: const Text('Initiate Emergency Administrative Succession'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessionCompletedCertificate(AdminContinuityConfig config) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _emerald, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: _emerald, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrative Succession Certificate',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _emerald,
                      ),
                    ),
                    Text(
                      'Emergency succession has been formally executed and recorded.',
                      style: GoogleFonts.inter(fontSize: 12, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.calendar_today_outlined, 'Succession Date', config.successionDate ?? 'Recorded'),
          _buildInfoRow(Icons.help_outline, 'Succession Reason', config.successionReason ?? 'Emergency Succession'),
          _buildInfoRow(Icons.description_outlined, 'Reference Doc', config.successionReference ?? 'Ref: Official Filing'),
          _buildInfoRow(Icons.person_remove_outlined, 'Former Administrator', '${config.formerAdminName} (${config.formerAdminEmail}) [DEACTIVATED]'),
          _buildInfoRow(Icons.person_outline, 'New Primary Admin', '${config.primaryAdminName} (${config.primaryAdminEmail}) [ACTIVE]'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              'Notice: To re-establish the redundancy chain, the new Primary Administrator should designate a new Authorized Backup Administrator.',
              style: GoogleFonts.inter(color: const Color(0xFF1E40AF), fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAssignBackupDialog(config),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Designate New Backup Administrator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showResetToBaselineDialog,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Revert to Baseline (Demo Reset)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Audit Trail ──────────────────────────────────────────────────

  Widget _buildAuditTrailTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Governance & Succession Audit Logs',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadAuditLogs,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Legal Succession Register (${_formalContinuityRecords.length})'),
                selected: _selectedAuditView == 0,
                onSelected: (v) => setState(() => _selectedAuditView = 0),
                selectedColor: _emerald,
                labelStyle: GoogleFonts.inter(
                  color: _selectedAuditView == 0 ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: Text('System Activity Logs (${_continuityAuditLogs.length})'),
                selected: _selectedAuditView == 1,
                onSelected: (v) => setState(() => _selectedAuditView = 1),
                selectedColor: _emerald,
                labelStyle: GoogleFonts.inter(
                  color: _selectedAuditView == 1 ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: _isLoadingLogs
                ? const Center(child: CircularProgressIndicator(color: _emerald))
                : _selectedAuditView == 0
                    ? _buildFormalRecordsList()
                    : _buildActivityLogsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormalRecordsList() {
    if (_formalContinuityRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 40, color: _slate),
            const SizedBox(height: 8),
            Text(
              'No formal continuity designations or succession records yet.',
              style: GoogleFonts.inter(color: _slate, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _formalContinuityRecords.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rec = _formalContinuityRecords[index];
        final eventType = (rec['event_type'] ?? 'DESIGNATION').toString();
        final isSuccession = eventType.contains('SUCCESSION');
        final createdAtStr = rec['created_at']?.toString() ?? '';
        final parsedDate = DateTime.tryParse(createdAtStr);
        final formattedDate = parsedDate != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(parsedDate.toLocal())
            : createdAtStr;

        final emergencyReason = rec['emergency_reason']?.toString();
        final refDoc = rec['reference_document']?.toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSuccession ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSuccession ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSuccession
                              ? _dangerRed.withValues(alpha: 0.15)
                              : _emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSuccession ? _dangerRed : _emerald,
                          ),
                        ),
                        child: Text(
                          eventType,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSuccession ? _dangerRed : _emerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: GoogleFonts.inter(fontSize: 11, color: _slate),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'STATUS: ${(rec['status'] ?? 'ACTIVE').toString().toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: _slate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isSuccession
                    ? 'Primary Administrator Handover: ${rec['primary_admin_name']} (${rec['primary_admin_email']}) ➔ ${rec['backup_admin_name']} (${rec['backup_admin_email']})'
                    : 'Designated Backup Administrator: ${rec['backup_admin_name']} (${rec['backup_admin_email']})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSuccession ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                ),
              ),
              if (emergencyReason != null && emergencyReason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Emergency Reason: $emergencyReason',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)),
                ),
              ],
              if (refDoc != null && refDoc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Reference Document / Memo: $refDoc',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _emerald),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 13, color: _slate),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Initiated by: ${rec['initiated_by_name'] ?? 'System'} (${rec['initiated_by_email'] ?? 'system'})',
                      style: GoogleFonts.inter(fontSize: 10.5, color: _slate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityLogsList() {
    if (_continuityAuditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 40, color: _slate),
            const SizedBox(height: 8),
            Text(
              'No administrative continuity events logged yet.',
              style: GoogleFonts.inter(color: _slate, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _continuityAuditLogs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = _continuityAuditLogs[index];
        final isEmergency = log.action.contains('SUCCESSION');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isEmergency
                ? _dangerRed.withValues(alpha: 0.15)
                : _emerald.withValues(alpha: 0.1),
            child: Icon(
              isEmergency ? Icons.warning_rounded : Icons.shield_outlined,
              color: isEmergency ? _dangerRed : _emerald,
              size: 18,
            ),
          ),
          title: Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                log.action,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isEmergency ? _dangerRed : const Color(0xFF0F172A),
                ),
              ),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt),
                style: GoogleFonts.inter(fontSize: 10, color: _slate),
              ),
            ],
          ),
          subtitle: Text(
            log.description,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
          ),
          trailing: Text(
            log.userEmail,
            style: GoogleFonts.inter(fontSize: 11, color: _slate),
          ),
        );
      },
    );
  }



  // ─── Modals / Dialogs ────────────────────────────────────────────────────

  void _showConfirmToggleAuthorityDialog(AdminContinuityConfig config, String newMode) {
    final isAuthorizing = newMode == 'co_admin';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isAuthorizing ? Icons.verified_user_rounded : Icons.lock_clock_rounded,
              color: isAuthorizing ? _emerald : _goldDark,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isAuthorizing ? 'Authorize Co-Admin Access?' : 'Restrict to Standby Mode?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAuthorizing
                    ? 'By authorizing Co-Admin access, ${config.backupAdminName} (${config.backupAdminEmail}) will be permitted to log in through the Staff & Admin Login portal for daily administrative duties alongside the Primary Admin.'
                    : 'By restricting to Standby mode, normal staff login for ${config.backupAdminName} (${config.backupAdminEmail}) will be locked. Administrative privileges will only activate in an Emergency Administrative Succession.',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAuthorizing ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAuthorizing ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAuthorizing ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                      size: 16,
                      color: isAuthorizing ? _emerald : _goldDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAuthorizing
                            ? 'Dual Control principle active. Action will be recorded in the immutable Audit Trail.'
                            : 'Least Privilege principle active. Action will be recorded in the immutable Audit Trail.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isAuthorizing ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final currentAuthUser = Supabase.instance.client.auth.currentUser;
              final updatedBy = currentAuthUser?.email ?? config.primaryAdminEmail;
              final updatedByName = currentAuthUser?.userMetadata?['name']?.toString() ?? config.primaryAdminName;

              final ok = await AdminContinuityService.setBackupAuthorityMode(
                mode: newMode,
                updatedByEmail: updatedBy,
                updatedByName: updatedByName,
              );

              if (ok) {
                GlobalMessenger.showSuccess(
                  isAuthorizing
                      ? 'Backup Administrator authorized as active Co-Admin. Normal admin login enabled.'
                      : 'Backup Administrator restricted to Standby. Normal admin login locked.',
                );
                _loadData();
              } else {
                GlobalMessenger.showError('Failed to update authority mode.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAuthorizing ? _emerald : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            child: Text(isAuthorizing ? 'Confirm & Authorize' : 'Confirm & Restrict'),
          ),
        ],
      ),
    );
  }

  void _showAssignBackupDialog(AdminContinuityConfig config) {
    final emailController = TextEditingController(text: config.backupAdminEmail);
    final nameController = TextEditingController(text: config.backupAdminName);
    final phoneController = TextEditingController(text: config.backupAdminPhone);
    final titleController = TextEditingController(text: config.backupAdminTitle);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Designate Authorized Backup Admin',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The designated backup administrator must be an individual management representative with their own separate email and credentials.',
                    style: GoogleFonts.inter(fontSize: 12, color: _slate),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Named Email Address *',
                      hintText: 'e.g. assistant.mgr@yangchow.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      if (v.trim().toLowerCase() == config.primaryAdminEmail.toLowerCase()) {
                        return 'Backup admin cannot be the same as Primary Admin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Steve Rogers',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Official Title / Department',
                      hintText: 'e.g. Operations Supervisor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Phone',
                      hintText: '+63 917 234 5678',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              final currentAuthUser = Supabase.instance.client.auth.currentUser;
              final assignedBy = currentAuthUser?.email ?? config.primaryAdminEmail;

              final ok = await AdminContinuityService.assignBackupAdmin(
                backupEmail: emailController.text.trim(),
                backupName: nameController.text.trim(),
                backupPhone: phoneController.text.trim(),
                backupTitle: titleController.text.trim(),
                assignedByEmail: assignedBy,
                assignedByName: currentAuthUser?.userMetadata?['name']?.toString() ?? 'Primary Admin',
              );

              if (ok) {
                GlobalMessenger.showSuccess('Authorized Backup Administrator successfully designated.');
                _loadData();
              } else {
                GlobalMessenger.showError('Failed to save Backup Administrator.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Designation'),
          ),
        ],
      ),
    );
  }

  void _showUpdatePrimaryDialog(AdminContinuityConfig config) {
    final nameController = TextEditingController(text: config.primaryAdminName);
    final phoneController = TextEditingController(text: config.primaryAdminPhone);
    final titleController = TextEditingController(text: config.primaryAdminTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Primary Admin Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Official Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final currentAuthUser = Supabase.instance.client.auth.currentUser;
              final ok = await AdminContinuityService.updatePrimaryAdminInfo(
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                title: titleController.text.trim(),
                updatedByEmail: currentAuthUser?.email ?? config.primaryAdminEmail,
              );
              if (ok) {
                GlobalMessenger.showSuccess('Primary Administrator profile updated.');
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _emerald, foregroundColor: Colors.white),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(String adminEmail, String adminName) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: _emerald, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Admin Password',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      'Update credentials for $adminEmail',
                      style: GoogleFonts.inter(fontSize: 11, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, size: 16, color: _emerald),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Direct Supabase Auth password update. Minimum 6 characters required.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF166534)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password *',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'New password is required';
                        if (v.trim().length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password *',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please confirm password';
                        if (v != newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);

                      final currentAuthUser = Supabase.instance.client.auth.currentUser;
                      final updatedByName = currentAuthUser?.userMetadata?['name']?.toString() ?? adminName;

                      final result = await AdminContinuityService.updateAdminPassword(
                        adminEmail: adminEmail,
                        newPassword: newPasswordController.text.trim(),
                        updatedByName: updatedByName,
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        if (result['success'] == true) {
                          GlobalMessenger.showSuccess(result['message'] ?? 'Password updated!');
                        } else {
                          GlobalMessenger.showError(result['message'] ?? 'Failed to update password.');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _emerald, foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog(String adminEmail, String adminName) {
    final newEmailController = TextEditingController();
    final confirmEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Admin Email',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      'Current Email: $adminEmail',
                      style: GoogleFonts.inter(fontSize: 11, color: _slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Instant Auto-Confirm: Your email is immediately updated in Supabase Auth and Admin records. No waiting for confirmation email links.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF0369A1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: adminEmail,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Current Email (Active)',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'New Email Address *',
                        hintText: 'e.g. newadmin@gmail.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'New email is required';
                        final trimmed = v.trim().toLowerCase();
                        if (!trimmed.contains('@') || !trimmed.contains('.')) return 'Enter a valid email address';
                        if (trimmed == adminEmail.toLowerCase()) return 'New email must be different from current email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Email Address *',
                        prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please confirm new email';
                        if (v.trim().toLowerCase() != newEmailController.text.trim().toLowerCase()) {
                          return 'Email addresses do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password (Verification) *',
                        hintText: 'Enter current admin password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Current password is required for security verification';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);

                      final currentAuthUser = Supabase.instance.client.auth.currentUser;
                      final updatedByName = currentAuthUser?.userMetadata?['name']?.toString() ?? adminName;

                      final result = await AdminContinuityService.updateAdminEmail(
                        oldEmail: adminEmail,
                        newEmail: newEmailController.text.trim(),
                        currentPassword: passwordController.text.trim(),
                        updatedByName: updatedByName,
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        if (result['success'] == true) {
                          GlobalMessenger.showSuccess(result['message'] ?? 'Email updated!');
                          _loadData();
                        } else {
                          GlobalMessenger.showError(result['message'] ?? 'Failed to update email.');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Email'),
            ),
          ],
        ),
      ),
    );
  }


  void _showUpdateSecurityKeyDialog(AdminContinuityConfig config) {
    final keyController = TextEditingController(text: config.securityVerificationKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Continuity Security Key', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This passphrase is required to authorize and execute an Emergency Administrative Succession.',
                style: GoogleFonts.inter(fontSize: 12, color: _slate),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Security Verification Key *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (keyController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final currentAuthUser = Supabase.instance.client.auth.currentUser;
              final ok = await AdminContinuityService.updateSecurityKey(
                newKey: keyController.text.trim(),
                updatedByEmail: currentAuthUser?.email ?? config.primaryAdminEmail,
              );
              if (ok) {
                GlobalMessenger.showSuccess('Continuity Security Verification Key updated.');
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _emerald, foregroundColor: Colors.white),
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  void _showInitiateSuccessionDialog(AdminContinuityConfig config) {
    final reasonController = TextEditingController(text: 'Permanent Medical Incapacitation / Deceased');
    final referenceController = TextEditingController();
    final keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 24),
            const SizedBox(width: 8),
            Text(
              'Execute Emergency Succession',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _dangerRed),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      'CAUTION: This will transfer Primary Administrator authority to:\n'
                      '• ${config.backupAdminName} (${config.backupAdminEmail})\n\n'
                      'The current Primary Admin account (${config.primaryAdminEmail}) will be DEACTIVATED to prevent unauthorized access. '
                      'All historical records will remain preserved.',
                      style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: reasonController.text,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Reason *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Permanent Medical Incapacitation / Deceased',
                        child: Text('Permanent Medical Incapacitation / Deceased'),
                      ),
                      DropdownMenuItem(
                        value: 'Sudden Executive Departure / Incommunicado',
                        child: Text('Sudden Executive Departure / Incommunicado'),
                      ),
                      DropdownMenuItem(
                        value: 'Disaster Recovery / Unrecoverable Loss',
                        child: Text('Disaster Recovery / Unrecoverable Loss'),
                      ),
                      DropdownMenuItem(
                        value: 'Court / Legal / Governance Directive',
                        child: Text('Court / Legal / Governance Directive'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) reasonController.text = val;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Official Reference Document Number *',
                      hintText: 'e.g. HR-MEMO-2026-004, CERT-INCIDENT-882',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Reference document is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Continuity Security Verification Key *',
                      hintText: 'Enter authorization key',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Security key is required' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              final currentAuthUser = Supabase.instance.client.auth.currentUser;
              final initiatedBy = currentAuthUser?.email ?? config.backupAdminEmail;
              final initiatedName = currentAuthUser?.userMetadata?['name']?.toString() ?? 'Authorized Successor';

              final res = await AdminContinuityService.executeEmergencySuccession(
                emergencyReason: reasonController.text.trim(),
                referenceDocument: referenceController.text.trim(),
                verificationKeyInput: keyController.text.trim(),
                initiatedByEmail: initiatedBy,
                initiatedByName: initiatedName,
              );

              if (res['success'] == true) {
                GlobalMessenger.showSuccess(res['message'] ?? 'Emergency succession executed.');
                _loadData();
              } else {
                GlobalMessenger.showError(res['message'] ?? 'Emergency succession failed.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, foregroundColor: Colors.white),
            child: const Text('Authorize & Execute Succession'),
          ),
        ],
      ),
    );
  }

  void _showResetToBaselineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: _emerald, size: 24),
            const SizedBox(width: 8),
            Text(
              'Reset Demo Continuity Baseline',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Revert continuity state back to the original baseline?\n\n'
          '• Primary Admin: Tony Stark (admn.pagsanjan@gmail.com) [ACTIVE]\n'
          '• Backup Admin: IT Administrator (yangchowit@gmail.com) [STANDBY]\n'
          '• Account Status: Continuity Protected\n\n'
          'This is designed for practice, testing, and thesis panel demonstrations.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminContinuityService.resetToOriginalBaseline();
              if (ok) {
                GlobalMessenger.showSuccess('Continuity baseline successfully restored to Tony Stark!');
                _loadData();
              } else {
                GlobalMessenger.showError('Failed to reset baseline.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore Baseline'),
          ),
        ],
      ),
    );
  }
}
