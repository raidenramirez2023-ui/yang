import 'dart:async';

import 'package:flutter/material.dart';



import 'package:supabase_flutter/supabase_flutter.dart';



import 'package:google_sign_in/google_sign_in.dart';



import 'package:yang_chow/utils/app_theme.dart';



import 'package:yang_chow/utils/role_helper.dart';



import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/services/app_settings_service.dart';



import 'package:yang_chow/pages/admin/user_management.dart';

import 'package:yang_chow/pages/admin/admin_menu_management_page.dart';



import 'package:yang_chow/pages/admin/sales_report_page.dart';

import 'package:yang_chow/pages/admin/customer_management_page.dart';



import 'package:yang_chow/pages/staff/inventory_management.dart';



import 'package:yang_chow/pages/admin/admin_dashboard.dart';



import 'package:yang_chow/pages/admin/admin_reservations_page.dart';





import 'package:yang_chow/pages/admin/admin_announcements_page.dart';



import 'package:yang_chow/pages/admin/admin_chat_page.dart';



import 'package:yang_chow/pages/admin/inventory_forecast_page.dart';



import 'package:yang_chow/pages/admin/payment_approval_page.dart';

import 'package:yang_chow/pages/admin/petty_cash_page.dart';

import 'package:yang_chow/pages/admin/refund_management_page.dart';
import 'package:yang_chow/pages/admin/audit_logs_page.dart';
import 'package:yang_chow/pages/admin/account_deletion_requests_page.dart';

import 'package:yang_chow/widgets/admin_chat_modal.dart';



import 'package:yang_chow/services/notification_service.dart';




import 'package:yang_chow/utils/url_sync_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/it_access_service.dart';

class _AdminNavGroup {
  final String title;
  final List<int> indices;
  const _AdminNavGroup({required this.title, required this.indices});
}

class AdminMainPage extends StatefulWidget {
  final int initialIndex;

  const AdminMainPage({super.key, this.initialIndex = 0});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  late int _selectedIndex;
  void Function()? _cancelPopState;

  int _pendingPaymentCount = 0;
  int _pendingReservationCount = 0;
  int _remainingBalanceCount = 0;
  int _pendingRefundCount = 0;
  int _pendingDeletionCount = 0;
  bool _isMaintenanceActive = false;
  Map<String, dynamic>? _activeItSession;



  late Timer? _countRefreshTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _adminNotifsSubscription;
  final Set<String> _shownToastAdminNotificationIds = {};

  // ── Top Toast Notification Overlay ──
  OverlayEntry? _currentAdminTopToastEntry;
  Timer? _adminTopToastTimer;

  void _dismissAdminTopToast() {
    _adminTopToastTimer?.cancel();
    _adminTopToastTimer = null;
    _currentAdminTopToastEntry?.remove();
    _currentAdminTopToastEntry = null;
  }

  void _showAdminTopToast({
    required Widget content,
    Duration? duration,
  }) {
    if (!mounted) return;
    _dismissAdminTopToast();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AdminTopToastWidget(
        onDismiss: () {
          if (_currentAdminTopToastEntry == entry) {
            _dismissAdminTopToast();
          }
        },
        duration: duration,
        child: content,
      ),
    );

    _currentAdminTopToastEntry = entry;
    overlay.insert(entry);

    if (duration != null) {
      _adminTopToastTimer = Timer(duration, () {
        if (_currentAdminTopToastEntry == entry) {
          _dismissAdminTopToast();
        }
      });
    }
  }

  bool _isStaffDelegationEnabled = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _syncUrl();
    _cancelPopState = UrlSyncHelper.listenPopState((path) {
      final idx = _pageUrls.indexOf(path);
      if (idx != -1 && idx != _selectedIndex && mounted) {
        setState(() => _selectedIndex = idx);
      }
    });

    _checkUserRole();
    _loadDelegationSetting();
    _loadMaintenanceStatus();
    _loadPendingPaymentCount();
    _loadPendingReservationCount();
    _loadRemainingBalanceCount();
    _loadPendingRefundCount();
    _loadPendingDeletionCount();
    _checkActiveItSession();

    // Start periodic refresh for counts (reduced frequency to prevent database issues)
    _countRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadPendingPaymentCount();
      _loadPendingReservationCount();
      _loadRemainingBalanceCount();
      _loadPendingRefundCount();
      _loadPendingDeletionCount();
      _checkActiveItSession();
    });

    NotificationService.startStockMonitoring();

    // Listen to admin notifications in real-time to show floating toast banner and update sidebar badges
    _adminNotifsSubscription = NotificationService.getAdminOnlyNotificationsStream().listen((notifs) {
      if (!mounted) return;
      _loadPendingPaymentCount();
      _loadPendingReservationCount();
      _loadRemainingBalanceCount();
      _loadPendingRefundCount();
      _loadPendingDeletionCount();

      final unread = notifs.where((n) => n['is_read'] == false).toList();
      if (unread.isNotEmpty) {
        final latest = unread.first;
        final id = latest['id']?.toString();
        if (id != null && !_shownToastAdminNotificationIds.contains(id)) {
          _shownToastAdminNotificationIds.add(id);
          _showAdminNotificationToast(latest);
        }
      }
    });
  }

  Future<void> _checkActiveItSession() async {
    try {
      final active = await ItAccessService.getActiveRequest();
      if (mounted) {
        setState(() {
          _activeItSession = active;
        });
      }
    } catch (e) {
      debugPrint('[Admin] Error checking active IT session: $e');
    }
  }

  Future<void> _loadMaintenanceStatus() async {
    try {
      final result = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'maintenance_mode_enabled')
          .maybeSingle();
      final active =
          result != null && result['setting_value']?.toString().toLowerCase() == 'true';
      if (mounted) {
        setState(() {
          _isMaintenanceActive = active;
          if (active && !_isPageAllowedDuringMaintenance(_selectedIndex)) {
            _selectedIndex = 1; // Auto redirect to Sales Reports (Export Allowed)
            _syncUrl();
          }
        });
      }
    } catch (e) {
      debugPrint('[Admin] Error loading maintenance status: $e');
    }
  }

  Future<void> _checkUserRole() async {
    final isDev = await RoleHelper.isDeveloper();
    if (isDev) return; // Developer testing bypass

    final isAdmin = await RoleHelper.isAdmin();
    if (!isAdmin && mounted) {
      Navigator.pushReplacementNamed(context, '/staff/dashboard');
    }
  }

  Future<void> _loadDelegationSetting() async {
    // Query Supabase directly — bypass local cache which resets on logout
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'staff_delegation_mode')
          .maybeSingle();
      final enabled = response != null &&
          (response['setting_value'] == 'true' || response['setting_value'] == '1');
      if (mounted) {
        setState(() {
          _isStaffDelegationEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint('[Admin] Error loading delegation setting: $e');
    }
  }

  Future<void> _toggleStaffDelegation(bool newValue) async {
    if (_isMaintenanceActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cannot modify duty delegation while system maintenance is active.'),
          backgroundColor: Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              newValue ? Icons.beach_access_rounded : Icons.admin_panel_settings_rounded,
              color: newValue ? const Color(0xFF0D9488) : const Color(0xFF14332E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                newValue ? 'Turn ON Rest Day Mode?' : 'Return to Admin Duty?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          newValue
              ? 'When Rest Day Mode is ON, on-duty Staff / Cashier can approve reservations, verify GCash payment slips, and manage balances from the Staff POS terminal.\n\nAll staff actions will still be recorded under their own name in Audit Logs.'
              : 'When Rest Day Mode is OFF, Staff approvals are locked. Transaction approvals and cancellations will be exclusive to Admin on duty.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? const Color(0xFF0D9488) : const Color(0xFF14332E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newValue ? 'Activate Rest Day Mode' : 'Return to Admin Duty'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppSettingsService().setStaffDelegationEnabled(newValue);
      setState(() {
        _isStaffDelegationEnabled = newValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? '✓ Rest Day Mode is ON: Staff can now process transactions.'
                : '✓ Rest Day Mode is OFF: Transaction approvals restricted to Admin.'),
            backgroundColor: newValue ? const Color(0xFF0D9488) : const Color(0xFF14332E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }







  Future<void> _loadPendingPaymentCount() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Count pending approval reservations
      final countResponse = await supabase
          .from('reservations')
          .select('id')
          .inFilter('status', ['pending_admin_approval', 'awaiting_verification'])
          .inFilter('payment_status', ['deposit_paid', 'fully_paid', 'pending_verification'])
          .eq('is_archived', false);

      // 2. Count pending approval advance orders
      int advanceCount = 0;
      try {
        final advCountResponse = await supabase
            .from('advance_orders')
            .select('id')
            .eq('status', 'awaiting_verification')
            .eq('payment_status', 'pending_verification');
        advanceCount = (advCountResponse as List).length;
      } catch (_) {}

      final totalPending = (countResponse as List).length + advanceCount;

      debugPrint('Pending payments count: $totalPending (Res: ${(countResponse as List).length}, Adv: $advanceCount)');

      if (mounted) {
        setState(() {
          _pendingPaymentCount = totalPending;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending payment count: $e');



      debugPrint('This might mean the SQL script hasn\'t been run yet or table doesn\'t exist');



      if (mounted) {



        setState(() {



          _pendingPaymentCount = 0;



        });



      }



    }



  }



  Future<void> _loadPendingReservationCount() async {

    try {

      final supabase = Supabase.instance.client;

      

      // Check if reservations table exists and get count of pending/new reservations

      await supabase

          .from('reservations')

          .select('id')

          .eq('is_archived', false)

          .inFilter('status', ['pending', 'pending_admin_approval', 'confirmed'])

          .limit(1); // Just check if table works



      // If we get here, table exists, now get full count

      final countResponse = await supabase

          .from('reservations')

          .select('id')

          .eq('is_archived', false)

          .eq('status', 'pending');



      debugPrint('Pending reservations only count: ${(countResponse as List).length}');



      if (mounted) {

        setState(() {

          _pendingReservationCount = (countResponse as List).length;

        });

      }

    } catch (e) {

      debugPrint('Error loading pending reservation count: $e');

      debugPrint('This might mean the SQL script hasn\'t been run yet or table doesn\'t exist');

      

      if (mounted) {

        setState(() {

          _pendingReservationCount = 0;

        });

      }

    }

  }



  Future<void> _loadRemainingBalanceCount() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Count reservations with deposit_paid status
      final reservationsCount = await supabase
          .from('reservations')
          .select('id, total_price, deposit_amount, payment_option, remaining_balance')
          .eq('payment_status', 'deposit_paid')
          .neq('is_archived', true);

      final totalCount = (reservationsCount as List).where((r) {
        final total = (r['total_price'] as num?)?.toDouble() ?? 0.0;
        final deposit = (r['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        final opt = r['payment_option']?.toString();
        final rem = (r['remaining_balance'] as num?)?.toDouble() ?? (total - deposit);
        return opt != 'full' && (total <= 0 || deposit < total) && rem > 0;
      }).length;
      
      debugPrint('Remaining balance count: $totalCount');

      if (mounted) {
        setState(() {
          _remainingBalanceCount = totalCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading remaining balance count: $e');

      

      if (mounted) {

        setState(() {

          _remainingBalanceCount = 0;

        });

      }

    }

  }



  Future<void> _loadPendingRefundCount() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Pending refunds from refunds table
      int refundsCount = 0;
      try {
        final refundRes = await supabase
            .from('refunds')
            .select('id')
            .eq('status', 'pending');
        refundsCount = (refundRes as List).length;
      } catch (e) {
        debugPrint('Error counting pending refunds: $e');
      }

      // 2. Pending reschedules from reschedule_requests table
      int reschedulesCount = 0;
      try {
        final rescheduleRes = await supabase
            .from('reschedule_requests')
            .select('id')
            .eq('status', 'pending');
        reschedulesCount = (rescheduleRes as List).length;
      } catch (e) {
        debugPrint('Error counting pending reschedules: $e');
      }

      final totalPending = refundsCount + reschedulesCount;

      if (mounted) {
        setState(() {
          _pendingRefundCount = totalPending;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending refund/reschedule count: $e');
    }
  }

  Future<void> _loadPendingDeletionCount() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('account_deletion_requests')
          .select('id')
          .or('status.eq.pending_review,status.eq.pending');

      if (mounted) {
        setState(() {
          _pendingDeletionCount = (res as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending deletion count: $e');
    }
  }



  @override
  void dispose() {
    NotificationService.stopStockMonitoring();
    _countRefreshTimer?.cancel();
    _adminNotifsSubscription?.cancel();
    _dismissAdminTopToast();
    _cancelPopState?.call();
    super.dispose();
  }

  static const List<String> _pageUrls = [
    '/admin/dashboard',
    '/admin/sales-reports',
    '/admin/inventory',
    '/admin/inventory-forecast',
    '/admin/menu-management',
    '/admin/reservations',
    '/admin/payment-management',
    '/admin/employee-management',
    '/admin/customers-reviews',
    '/admin/deletion-requests',
    '/admin/announcements',
    '/admin/customer-chat',
    '/admin/petty-cash',
    '/admin/refunds-reschedules',
    '/admin/audit-logs',
  ];

  void _syncUrl() {
    if (_selectedIndex >= 0 && _selectedIndex < _pageUrls.length) {
      UrlSyncHelper.updateUrl(_pageUrls[_selectedIndex]);
    }
  }

  void _onSelectTab(int index) {
    setState(() => _selectedIndex = index);
    _syncUrl();
  }

  /// Pages the admin is still allowed to access during system maintenance.
  /// These are read-only / export-only pages that do not trigger any
  /// approval, confirmation, or data-modification action.
  static const Set<int> _maintenanceAllowedPages = {
    0,  // Dashboard       – read-only overview
    1,  // Sales Reports   – export allowed
    2,  // Inventory       – view/export only (isViewOnly: true)
    3,  // Inventory Forecast – read-only
    5,  // Reservations    – scan pass & view only (actions locked)
    14, // Audit Logs      – read-only audit trail
  };

  bool _isPageAllowedDuringMaintenance(int index) {
    if (!_isMaintenanceActive) return true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email?.toLowerCase() == 'yangchowit@gmail.com') return true;
    return _maintenanceAllowedPages.contains(index);
  }

  void _showMaintenanceBlockDialog(int index) {
    final pageName = _pageTitles[index];
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  size: 32,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'System maintenance is currently active.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB45309),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  '"$pageName" is not accessible while maintenance is running.\n\nYou may only export data from Sales Reports, Inventory, and Audit Logs during this period.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF78350F),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Understood',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    if (_isMaintenanceActive && !_isPageAllowedDuringMaintenance(_selectedIndex)) {
      return _buildMaintenanceRestrictedView();
    }
    if (_selectedIndex == 5) {
      return AdminReservationsPage(
        isMaintenanceActive: _isMaintenanceActive,
      );
    }
    return _pages[_selectedIndex];
  }

  Widget _buildMaintenanceRestrictedView() {
    final pageName = _pageTitles[_selectedIndex];
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFB45309),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Actions Temporarily Restricted',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SYSTEM MAINTENANCE IS ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB91C1C),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bawal magsagawa ng anumang aksyon (add, edit, approve, confirm, delete) sa "$pageName" habang aktibo ang maintenance upang maiwasan ang conflict sa system.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ang pwede mo lang magawa ngayon ay mag-export ng data:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onSelectTab(1),
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  label: const Text('Export Sales Reports', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onSelectTab(2),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: const Text('Export Inventory', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onSelectTab(14),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Export Audit Logs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Enterprise IT Support & Privileged Access Management ────────────────

  Widget _buildEnterpriseItSupportHeaderButton({bool isCompact = false}) {
    final hasActiveSession = _activeItSession != null;

    if (isCompact) {
      return IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              hasActiveSession ? Icons.shield_rounded : Icons.support_agent_rounded,
              color: hasActiveSession ? const Color(0xFF059669) : AppTheme.adminSecondaryText,
              size: 22,
            ),
            if (hasActiveSession)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        tooltip: hasActiveSession ? 'Elevated IT Session Active' : 'Enterprise IT Service Desk',
        onPressed: () => _showItAccessRequestDialog(initialTab: hasActiveSession ? 1 : 0),
      );
    }

    if (hasActiveSession) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showItAccessRequestDialog(initialTab: 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.shield_rounded, color: Color(0xFF047857), size: 16),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IT SESSION ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      ItAccessService.getRemainingTimeString(_activeItSession!),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _showItAccessRequestDialog(initialTab: 0),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF1E40AF)),
      label: Text(
        'IT Support Desk',
        style: GoogleFonts.inter(
          color: const Color(0xFF334155),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSidebarItSupportTile({required bool isDrawer}) {
    final hasActiveSession = _activeItSession != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: hasActiveSession
              ? const Color(0xFF10B981).withValues(alpha: 0.12)
              : const Color(0xFF38BDF8).withValues(alpha: 0.08),
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            _showItAccessRequestDialog(initialTab: hasActiveSession ? 1 : 0);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: hasActiveSession
                  ? const Color(0xFF065F46).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasActiveSession
                    ? const Color(0xFF10B981).withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasActiveSession ? Icons.shield_rounded : Icons.terminal_rounded,
                  color: hasActiveSession ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            hasActiveSession ? 'IT SESSION ACTIVE' : 'IT Service Desk',
                            style: TextStyle(
                              color: hasActiveSession ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (hasActiveSession) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        hasActiveSession
                            ? ItAccessService.getRemainingTimeString(_activeItSession!)
                            : 'Access & Incident Control',
                        style: TextStyle(
                          color: hasActiveSession ? const Color(0xFFA7F3D0) : const Color(0xFF64748B),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 11,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showItAccessRequestDialog({int initialTab = 0}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EnterpriseItSupportDialog(
        initialTab: initialTab,
        activeItSession: _activeItSession,
        user: user,
        onSessionUpdated: _checkActiveItSession,
      ),
    );
  }

  static const List<String> _pageTitles = [
    'Dashboard',
    'Sales Reports',
    'Inventory',
    'Inventory Forecast',
    'Menu Management',
    'Reservations',
    'Payment Management',
    'Employee Management',
    'Customers & Reviews',
    'Deletion Requests',
    'Announcements',
    'Customer Chat',
    'Petty Cash',
    'Refunds & Reschedules',
    'Audit Logs',
  ];

  static const List<IconData> _pageIcons = [
    Icons.dashboard,
    Icons.analytics,
    Icons.inventory_2,
    Icons.trending_up,
    Icons.restaurant_menu,
    Icons.event_available,
    Icons.payment,
    Icons.people,
    Icons.groups_rounded,
    Icons.person_remove_rounded,
    Icons.campaign,
    Icons.chat_bubble,
    Icons.account_balance_wallet,
    Icons.receipt_long,
    Icons.shield_outlined,
  ];

  late final List<Widget> _pages = [
    const AdminDashboardPage(),
    const SalesReportPage(),
    const InventoryPage(isViewOnly: true, showImportExport: true),
    const InventoryForecastPage(),
    const AdminMenuManagementPage(),
    const AdminReservationsPage(),
    const PaymentApprovalPage(),
    const UserManagementPage(),
    const CustomerManagementPage(),
    const AccountDeletionRequestsPage(),
    const AdminAnnouncementsPage(),
    const AdminChatPage(),
    const PettyCashPage(),
    const RefundManagementPage(),
    const AuditLogsPage(),
  ];







  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final useDrawer = ResponsiveUtils.shouldUseDrawer(context);

    Widget layout;
    if (isDesktop || isTablet) {
      layout = _buildDesktopLayout();
    } else if (useDrawer) {
      layout = _buildWebMobileLayout();
    } else {
      layout = _buildMobileLayout();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          _showLogoutDialog(context);
        }
      },
      child: Column(
        children: [
          // ── Maintenance Warning Banner (Top) ──
          if (_isMaintenanceActive)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFF92400E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pulsing dot + icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Icon(Icons.engineering_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Label + details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFCA5A5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SYSTEM MAINTENANCE IS ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'System maintenance is currently running. All actions and modifications are restricted. Data export is permitted.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBannerRestrictionChip(Icons.lock_rounded, 'Actions Locked'),
                            _buildBannerRestrictionChip(Icons.money_off_rounded, 'Payments'),
                            _buildBannerAllowedChip(Icons.qr_code_scanner_rounded, 'Scan Pass Allowed'),
                            _buildBannerAllowedChip(Icons.file_download_outlined, 'Export Allowed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),



                  // Refresh button
                  GestureDetector(
                    onTap: _loadMaintenanceStatus,
                    child: Tooltip(
                      message: 'Refresh status',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Refresh',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: layout),
        ],
      ),
    );
  }







  Widget _buildBannerRestrictionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block_rounded, size: 10, color: Color(0xFFFCA5A5)),
          const SizedBox(width: 4),
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAllowedChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF065F46).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF6EE7B7)),
          const SizedBox(width: 4),
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {

    return Container(
      color: AppTheme.adminMainBackground,

      child: Scaffold(

        backgroundColor: Colors.transparent,

        body: Stack(

          children: [

            Row(

              children: [

                _buildSidebar(),

                Expanded(

                  child: Column(

                    children: [

                      _buildModernAppBar(),

                      Expanded(

                        child: Container(

                          padding: const EdgeInsets.all(24),

                          child: _buildCurrentPage(),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

            // Chat Modal Overlay

            const AdminChatModal(),

          ],

        ),

      ),

    );
  }

  Widget _buildNavBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static const List<_AdminNavGroup> _adminNavGroups = [
    _AdminNavGroup(
      title: 'OVERVIEW',
      indices: [0, 1], // Dashboard, Sales Reports
    ),
    _AdminNavGroup(
      title: 'OPERATIONS',
      indices: [5, 4, 2, 3], // Reservations, Menu Management, Inventory, Inventory Forecast
    ),
    _AdminNavGroup(
      title: 'FINANCE & PAYMENTS',
      indices: [6, 13, 12], // Payment Management, Refunds & Reschedules, Petty Cash
    ),
    _AdminNavGroup(
      title: 'ADMIN & SYSTEM',
      indices: [7, 8, 9, 11, 10, 14], // Employee Management, Customers & Reviews, Deletion Requests, Customer Chat, Announcements, Audit Logs
    ),
  ];

  String _getCategoryForIndex(int index) {
    for (final group in _adminNavGroups) {
      if (group.indices.contains(index)) {
        return group.title;
      }
    }
    return 'ADMIN';
  }

  Widget _buildCategorizedNavList({required bool isDrawer}) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        for (final group in _adminNavGroups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 6),
            child: Row(
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Color(0xFF8BAAA4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
          for (final index in group.indices)
            _buildNavTile(index: index, isDrawer: isDrawer),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNavTile({required int index, required bool isDrawer}) {
    final isSelected = _selectedIndex == index;
    final isBlocked = !_isPageAllowedDuringMaintenance(index);

    // Badges calculation - exactly preserves existing logic
    int badgeCount = 0;
    if (_pageTitles[index] == 'Reservations') {
      badgeCount = _pendingReservationCount;
    } else if (_pageTitles[index] == 'Payment Management') {
      badgeCount = _pendingPaymentCount + _remainingBalanceCount;
    } else if (_pageTitles[index] == 'Refunds & Reschedules' || _pageTitles[index] == 'Refund Management') {
      badgeCount = _pendingRefundCount;
    } else if (_pageTitles[index] == 'Deletion Requests') {
      badgeCount = _pendingDeletionCount;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(
        opacity: isBlocked ? 0.45 : 1.0,
        child: Material(
          color: isSelected && !isBlocked ? AppTheme.activeSidebarItemBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: isBlocked
                ? const Color(0xFFB45309).withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.05),
            onTap: () {
              // ── Maintenance guard ──
              if (isBlocked) {
                _showMaintenanceBlockDialog(index);
                return;
              }

              _onSelectTab(index);

              // Refresh count when switching to Payment Management
              if (_pageTitles[index] == 'Payment Management') {
                if (mounted) {
                  setState(() {
                    _pendingPaymentCount = 0;
                    _remainingBalanceCount = 0;
                  });
                }
              }

              // Refresh count when switching to Reservations
              if (_pageTitles[index] == 'Reservations') {
                if (mounted) {
                  setState(() {
                    _pendingReservationCount = 0;
                  });
                }
              }

              // Refresh count when switching to Refunds & Reschedules
              if (_pageTitles[index] == 'Refunds & Reschedules') {
                _loadPendingRefundCount();
              }

              // Refresh count when switching to Deletion Requests
              if (_pageTitles[index] == 'Deletion Requests') {
                _loadPendingDeletionCount();
              }

              if (isDrawer) {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (isSelected && !isBlocked)
                    Container(
                      width: 3.5,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.activeSidebarAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 0),
                  Icon(
                    _pageIcons[index],
                    size: 19,
                    color: isBlocked
                        ? const Color(0xFF92400E).withValues(alpha: 0.8)
                        : isSelected
                            ? AppTheme.activeSidebarAccent
                            : const Color(0xFFC7D6D3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pageTitles[index],
                      style: TextStyle(
                        fontWeight: isSelected && !isBlocked ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                        color: isBlocked
                            ? const Color(0xFFFDE68A)
                            : isSelected
                                ? Colors.white
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  if (isBlocked)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Color(0xFFFCA5A5),
                      ),
                    )
                  else if (_isMaintenanceActive && index == 5)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF2DD4BF), width: 0.8),
                      ),
                      child: Text(
                        'SCAN',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2DD4BF),
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  else if (badgeCount > 0)
                    _buildNavBadge(badgeCount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Material(
      color: AppTheme.adminSidebarBackground,
      child: SizedBox(
        width: 260,
        child: Column(
          children: [
            // Brand Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/yang_chow_logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.adminActiveSidebarAccent,
                                Color(0xFFB47D28),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YANG CHOW',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Admin Portal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.sidebarSubtitle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 8),

            // Categorized Navigation List
            Expanded(
              child: _buildCategorizedNavList(isDrawer: false),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Pinned Enterprise IT Support Dock Tile
            _buildSidebarItSupportTile(isDrawer: false),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Sidebar Footer: Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: Colors.redAccent.withValues(alpha: 0.12),
                  onTap: () => _showLogoutDialog(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 19),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffDelegationToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isStaffDelegationEnabled
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isStaffDelegationEnabled
              ? const Color(0xFF6EE7B7)
              : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isStaffDelegationEnabled
                ? Icons.beach_access_rounded
                : Icons.admin_panel_settings_rounded,
            size: 16,
            color: _isStaffDelegationEnabled
                ? const Color(0xFF059669)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isStaffDelegationEnabled
                    ? 'REST DAY MODE: ON'
                    : 'ADMIN DUTY: ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: _isStaffDelegationEnabled
                      ? const Color(0xFF065F46)
                      : const Color(0xFF334155),
                ),
              ),
              Text(
                _isStaffDelegationEnabled
                    ? 'Staff Delegation Active'
                    : 'Staff Approvals Locked',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _isStaffDelegationEnabled
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _isStaffDelegationEnabled,
              activeThumbColor: const Color(0xFF059669),
              activeTrackColor: const Color(0xFFA7F3D0),
              inactiveThumbColor: const Color(0xFF94A3B8),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              onChanged: _toggleStaffDelegation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final category = _getCategoryForIndex(_selectedIndex);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Breadcrumb & Page Title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppTheme.adminSecondaryText,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppTheme.adminSecondaryText,
                    ),
                  ),
                  Text(
                    _pageTitles[_selectedIndex],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.adminPrimaryAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _pageTitles[_selectedIndex],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.adminPrimaryText,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildStaffDelegationToggle(),
          const SizedBox(width: 12),
          _buildEnterpriseItSupportHeaderButton(),
          const SizedBox(width: 12),
          _buildAdminNotificationIcon(),
          const SizedBox(width: 16),
          // User Profile Block
          Row(
            children: [
              Container(height: 32, width: 1, color: AppTheme.cardBorder),
              const SizedBox(width: 20),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currentUser?.email?.split('@')[0] ?? 'Admin',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.adminPrimaryText,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'System Admin',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.adminSecondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFF8FAFC),
                      child: Icon(Icons.person_rounded, color: AppTheme.adminChatButton, size: 20),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildWebMobileLayout() {

    return Container(
      color: AppTheme.adminMainBackground,

      child: Scaffold(

        backgroundColor: Colors.transparent,

        appBar: _buildAppBarWithDrawer(),

        drawer: _buildDrawer(),

        body: Stack(

          children: [

            _buildCurrentPage(),

            // Chat Modal Overlay

            const AdminChatModal(),

          ],

        ),

      ),

    );

  }



  Widget _buildMobileLayout() {
    return Container(
      color: AppTheme.adminMainBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBarWithDrawer(),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            _buildCurrentPage(),
            const AdminChatModal(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }







  PreferredSizeWidget _buildAppBarWithDrawer() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        _pageTitles[_selectedIndex],
        style: const TextStyle(
          color: AppTheme.adminPrimaryText,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.adminSecondaryText),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      actions: [
        _buildEnterpriseItSupportHeaderButton(isCompact: true),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: _buildAdminNotificationIcon(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppTheme.cardBorder, height: 1),
      ),
    );
  }







  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.adminSidebarBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Brand Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/yang_chow_logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.adminActiveSidebarAccent,
                                Color(0xFFB47D28),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YANG CHOW',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Admin Portal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.sidebarSubtitle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),

            // Categorized Navigation List for Drawer
            Expanded(
              child: _buildCategorizedNavList(isDrawer: true),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Pinned Enterprise IT Support Dock Tile
            _buildSidebarItSupportTile(isDrawer: true),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // Drawer Footer: Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: Colors.redAccent.withValues(alpha: 0.12),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 19),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }







  Widget _buildBottomNavigationBar() {



    return BottomNavigationBar(



      currentIndex: _selectedIndex,



      onTap: (index) {
        if (!_isPageAllowedDuringMaintenance(index)) {
          _showMaintenanceBlockDialog(index);
          return;
        }
        setState(() => _selectedIndex = index);
      },



      type: BottomNavigationBarType.fixed,



      backgroundColor: AppTheme.white,



      selectedItemColor: AppTheme.adminChatButton,



      unselectedItemColor: AppTheme.mediumGrey,



      items: _pageTitles.asMap().entries.map((entry) {



        final index = entry.key;



        final title = entry.value;



        return BottomNavigationBarItem(



          icon: Icon(_pageIcons[index]),



          label: title,



        );



      }).toList(),



    );



  }







  void _showLogoutDialog(BuildContext context) {



    final isMobile = ResponsiveUtils.isMobile(context);







    showDialog(



      context: context,



      barrierDismissible: false,



      builder: (context) => AlertDialog(



        shape: RoundedRectangleBorder(



          borderRadius: BorderRadius.circular(AppTheme.radiusLg),



        ),



        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),



        title: Row(



          children: [



            Icon(



              Icons.logout,



              color: AppTheme.adminChatButton,



              size: ResponsiveUtils.getResponsiveIconSize(context),



            ),



            SizedBox(width: isMobile ? 8 : 12),



            Expanded(



              child: Text(



                'Logout',



                style: TextStyle(



                  fontSize: ResponsiveUtils.getResponsiveFontSize(



                    context,



                    mobile: 18,



                    tablet: 20,



                    desktop: 22,



                  ),



                  fontWeight: FontWeight.bold,



                ),



              ),



            ),



          ],



        ),



        content: Text(



          'Are you sure you want to logout?',



          style: TextStyle(



            fontSize: ResponsiveUtils.getResponsiveFontSize(



              context,



              mobile: 14,



              tablet: 16,



              desktop: 16,



            ),



          ),



        ),



        actions: [



          TextButton(



            onPressed: () => Navigator.pop(context),



            child: Text(



              'Cancel',



              style: TextStyle(



                fontSize: ResponsiveUtils.getResponsiveFontSize(



                  context,



                  mobile: 14,



                  tablet: 15,



                  desktop: 16,



                ),



              ),



            ),



          ),



          ElevatedButton(



            style: ElevatedButton.styleFrom(



              backgroundColor: AppTheme.errorRed,



              padding: EdgeInsets.symmetric(



                horizontal: isMobile ? 16 : 24,



                vertical: isMobile ? 8 : 12,



              ),



            ),



            onPressed: () async {
              _dismissAdminTopToast();
              _shownToastAdminNotificationIds.clear();
              Navigator.pop(context);
              final navigator = Navigator.of(context);
              await Supabase.instance.client.auth.signOut();
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              if (mounted) {
                navigator.pushReplacementNamed('/staff-login');
              }
            },



            child: Text(



              'Logout',



              style: TextStyle(



                fontSize: ResponsiveUtils.getResponsiveFontSize(



                  context,



                  mobile: 14,



                  tablet: 15,



                  desktop: 16,



                ),



              ),



            ),



          ),



        ],



      ),



    );



  }







  Widget _buildAdminNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getAdminOnlyNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n['is_read']).length;
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasUnread
                    ? const Color(0xFFF59E0B)
                    : AppTheme.adminSecondaryText,
                size: 24,
              ),
              onPressed: () => _showAdminNotificationsDialog(notifications),
              tooltip: hasUnread
                  ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                  : 'Notifications',
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444), // Vibrant Red
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAdminNotificationToast(Map<String, dynamic> n) {
    if (!mounted) return;
    final title = _getAdminNotificationTitle(n);
    final subtitle = _getAdminNotificationSubtitle(n);

    // Auto-dismiss after 5 seconds if VIEW is not clicked
    _showAdminTopToast(
      duration: const Duration(seconds: 5),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF0F172A)),
              label: Text(
                'VIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: () {
                _dismissAdminTopToast();
                NotificationService.getAdminOnlyNotificationsStream()
                    .first
                    .then((notifs) {
                  if (mounted) _showAdminNotificationsDialog(notifs);
                });
              },
            ),
          ],
        ),
      ),
    );
  }







  void _showAdminNotificationsDialog(List<Map<String, dynamic>> notifications) {
    NotificationService.markAllAsRead('', forAdmin: true);
    if (notifications.isNotEmpty) {
      final unreadIds = notifications
          .where((n) => n['is_read'] == false)
          .map((n) => n['id'].toString())
          .toList();
      if (unreadIds.isNotEmpty) {
        NotificationService.markVisibleAsRead(unreadIds);
      }
    }







    showDialog(



      context: context,



      builder: (context) => AlertDialog(



        title: const Text('Admin Notifications'),



        content: SizedBox(



          width: 400,



          height: 500,



          child: notifications.isEmpty



              ? const Center(child: Text('No new activity'))



              : ListView.separated(



                  itemCount: notifications.length,



                  separatorBuilder: (context, index) => const Divider(),



                  itemBuilder: (context, index) {



                    final n = notifications[index];



                    final date = DateTime.parse(n['created_at']).toLocal();



                    final timeStr = DateFormat('MMM d, h:mm a').format(date);







                    return ListTile(



                      leading: CircleAvatar(



                        backgroundColor: AppTheme.adminChatButton.withValues(



                          alpha: 0.1,



                        ),



                        child: Icon(



                          _getIconForAction(n['action_type']),



                          color: AppTheme.adminChatButton,



                          size: 20,



                        ),



                      ),



                      title: Text(



                        _getAdminNotificationTitle(n),



                        style: const TextStyle(



                          fontWeight: FontWeight.bold,



                          fontSize: 14,



                        ),



                      ),



                      subtitle: Column(



                        crossAxisAlignment: CrossAxisAlignment.start,



                        children: [



                          Text(

                            _getAdminNotificationSubtitle(n),

                          ),



                          Text(



                            timeStr,



                            style: const TextStyle(



                              fontSize: 10,



                              color: Colors.grey,



                            ),



                          ),



                        ],



                      ),



                    );



                  },



                ),



        ),



        actions: [



          TextButton(



            onPressed: () => Navigator.pop(context),



            child: const Text('Close'),



          ),



        ],



      ),



    );



  }







  IconData _getIconForAction(String action) {

    switch (action) {

      case 'stock_request':

        return Icons.inventory_2;

      case 'stock_alert':

        return Icons.warning_amber_rounded;

      case 'pos_order':

        return Icons.shopping_cart;

      case 'created':

        return Icons.add_circle;

      case 'cancelled':

      case 'deleted':

        return Icons.cancel;

      case 'paid':

        return Icons.payments;

      case 'updated':

        return Icons.edit;

      default:

        return Icons.notifications;

    }

  }



  String _getAdminNotificationSubtitle(Map<String, dynamic> n) {
    final actorName = n['actor_name'] ?? 'Customer';
    final actionType = n['action_type'];
    final rawEventType = (n['event_type'] ?? 'Reservation').toString();
    final eventType = rawEventType.replaceAll(
      RegExp(r'^\((?:Deposit Paid|Fully Paid|Remaining Balance Paid)\)\s*', caseSensitive: false),
      '',
    ).trim();

    if (actionType == 'stock_request') {
      return 'Kitchen has requested stock: $eventType';
    }
    if (actionType == 'stock_alert') {
      return eventType.isNotEmpty ? eventType : 'Stock Alert';
    }
    if (actionType == 'pos_order') {
      return 'POS staff have placed an order to process';
    }
    if (actionType == 'balance_cleared') {
      return '$actorName paid remaining balance for $eventType';
    }
    if (actionType == 'deposit_paid') {
      return '$actorName paid deposit for $eventType';
    }
    if (actionType == 'fully_paid') {
      return '$actorName completed full payment for $eventType';
    }
    if (actionType == 'paid') {
      return '$actorName paid for $eventType';
    }
    if (actionType == 'created') {
      return '$actorName submitted new reservation for $eventType';
    }

    return '$actorName: $actionType for $eventType';
  }

  String _getAdminNotificationTitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Stock Request';
    }
    if (n['action_type'] == 'stock_alert') {
      return 'Stock Alert';
    }
    if (n['action_type'] == 'pos_order') {
      return 'New Order';
    }

    switch (n['action_type']) {
      case 'created':
        return 'New Reservation';
      case 'cancelled':
        return 'Reservation Cancelled';
      case 'deleted':
        return 'Reservation Deleted';
      case 'deposit_paid':
        return 'Deposit Payment Received';
      case 'balance_cleared':
        return 'Remaining Balance Paid';
      case 'fully_paid':
        return 'Full Payment Received';
      case 'paid':
        return 'Payment Received';
      case 'balance_payment_link':
        return 'Payment Link Sent';
      case 'updated':
        return 'Reservation Modified';
      default:
        return 'Activity Alert';
    }
  }

}

/// Animated Top Toast Notification Banner for Admin
class _AdminTopToastWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Duration? duration;

  const _AdminTopToastWidget({
    required this.child,
    required this.onDismiss,
    this.duration,
  });

  @override
  State<_AdminTopToastWidget> createState() => _AdminTopToastWidgetState();
}

class _AdminTopToastWidgetState extends State<_AdminTopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding > 0 ? topPadding + 10 : 18,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnterpriseItSupportDialog extends StatefulWidget {
  final int initialTab;
  final Map<String, dynamic>? activeItSession;
  final User user;
  final VoidCallback onSessionUpdated;

  const _EnterpriseItSupportDialog({
    required this.initialTab,
    required this.activeItSession,
    required this.user,
    required this.onSessionUpdated,
  });

  @override
  State<_EnterpriseItSupportDialog> createState() => _EnterpriseItSupportDialogState();
}

class _EnterpriseItSupportDialogState extends State<_EnterpriseItSupportDialog> {
  late final TextEditingController _issueController;
  late int _currentTab;
  String _selectedSeverity = 'P2 - High';
  String _selectedScope = 'Payment Management + Sales Report';
  int _selectedDuration = 2;
  bool _autoPurgeTestData = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _activeSession;

  static const List<Map<String, dynamic>> _severityOptions = [
    {'code': 'P1 - Critical', 'desc': 'System Down / Payment Blocker', 'color': Color(0xFFDC2626)},
    {'code': 'P2 - High', 'desc': 'Feature Impaired / Sync Issue', 'color': Color(0xFFEA580C)},
    {'code': 'P3 - Standard', 'desc': 'General Maintenance / Config', 'color': Color(0xFF2563EB)},
  ];

  static const List<String> _scopeOptions = [
    'Payment Management + Sales Report',
    'Payment Approval Only',
    'Sales Report Only',
    'Reservations Management',
    'Full Admin Access',
  ];

  static const List<int> _durationOptions = [1, 2, 4, 8];

  @override
  void initState() {
    super.initState();
    _issueController = TextEditingController();
    _currentTab = widget.initialTab;
    _activeSession = widget.activeItSession;
  }

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final issueText = _issueController.text.trim();
    if (issueText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the technical issue or reason.'),
          backgroundColor: Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final adminName = widget.user.userMetadata?['full_name']?.toString() ??
        widget.user.userMetadata?['name']?.toString() ??
        widget.user.email?.split('@').first ?? 'Admin';

    final fullDescription = '[$_selectedSeverity] $issueText';

    final result = await ItAccessService.sendAccessRequest(
      adminEmail: widget.user.email!,
      adminName: adminName,
      issueDescription: fullDescription,
      accessScope: _selectedScope,
      durationHours: _selectedDuration,
      autoPurgeTestData: _autoPurgeTestData,
    );

    widget.onSessionUpdated();
    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (result != null) {
      if (mounted) Navigator.pop(context);
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ IT Support Request dispatched ($_selectedSeverity). Developer notified.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to dispatch request. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 620,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Enterprise Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Enterprise IT Service Desk',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'ITSM / PAM',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Privileged Access Elevation & Infrastructure Incident Support',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // ── Tab Bar Navigation ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _currentTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _currentTab == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
                            ),
                            boxShadow: _currentTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.post_add_rounded,
                                size: 16,
                                color: _currentTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Request Elevation',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: _currentTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: _currentTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _currentTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _currentTab == 1 ? const Color(0xFFCBD5E1) : Colors.transparent,
                            ),
                            boxShadow: _currentTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: _currentTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Session & Audit',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: _currentTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: _currentTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                              if (_activeSession != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab Content ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: _currentTab == 0
                      ? _buildElevationRequestTab()
                      : _buildActiveSessionAndAuditTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElevationRequestTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Incident Severity (ITIL)
        Row(
          children: [
            Text(
              'Incident Severity (ITIL)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 6),
            const Text('*', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _severityOptions.map((opt) {
            final isSelected = _selectedSeverity == opt['code'];
            final color = opt['color'] as Color;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedSeverity = opt['code'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      opt['code'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? color : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Issue Description
        Row(
          children: [
            Text(
              'Incident / Issue Description',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 6),
            const Text('*', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _issueController,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Payment not reconciling in sales report after GCash webhook failure',
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Access Scope Needed
        Text(
          'Target Access Scope (Least Privilege)',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedScope,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
              items: _scopeOptions
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B))),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedScope = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Duration Chips
        Text(
          'Time-Bound Session Duration',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _durationOptions.map((h) {
            final selected = _selectedDuration == h;
            return GestureDetector(
              onTap: () => setState(() => _selectedDuration = h),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '${h}h window',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Auto-purge safeguard
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _autoPurgeTestData,
                activeColor: const Color(0xFFDC2626),
                checkColor: Colors.white,
                onChanged: (val) {
                  setState(() => _autoPurgeTestData = val ?? true);
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-purge test payments & orders upon completion',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prevents test orders and diagnostic payments from skewing production accounting & sales reports.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB91C1C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Compliance Info Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Governance Protocol: Elevation requires developer confirmation. All actions during elevated sessions are logged to the immutable Audit Trail and auto-expire after $_selectedDuration hour(s).',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _submitRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isSubmitting ? 'Dispatching...' : 'Dispatch IT Request',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSessionAndAuditTab() {
    final hasActive = _activeSession != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Active Session Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasActive ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: hasActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasActive ? Icons.shield_rounded : Icons.check_circle_outline_rounded,
                    color: hasActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasActive ? 'ELEVATED SESSION IN PROGRESS' : 'Standard Role Isolation Active',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: hasActive ? const Color(0xFF065F46) : const Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  if (hasActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(
                            ItAccessService.getRemainingTimeString(_activeSession!),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasActive
                    ? 'Developer yangchowit@gmail.com currently has temporary elevated administrative access under scope "${_activeSession!['access_scope'] ?? 'General'}".'
                    : 'No external engineer currently possesses elevated access to Yang Chow systems.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: hasActive ? const Color(0xFF047857) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (hasActive) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    foregroundColor: const Color(0xFFDC2626),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                            const SizedBox(width: 10),
                            Text('Revoke IT Access?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to terminate the developer\'s elevated session immediately? Any pending diagnostic tasks will be stopped.',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: Text('Revoke Immediately', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final ok = await ItAccessService.revokeRequest(_activeSession!['id'], widget.user.email!);
                      final updatedActive = await ItAccessService.getActiveRequest();
                      widget.onSessionUpdated();
                      if (mounted) {
                        setState(() => _activeSession = updatedActive);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '🔒 Elevated access revoked.' : 'Failed to revoke access.'),
                            backgroundColor: ok ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                  label: Text('Revoke Access Immediately (Kill Switch)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Recent Requests & Audit Trail ──
        Text(
          'Recent IT Elevation History',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: ItAccessService.getAdminRequests(widget.user.email!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'No recent IT access requests found.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final r = requests[index];
                final status = (r['status'] ?? 'pending').toString().toLowerCase();
                final requestedAt = DateTime.tryParse(r['requested_at'] ?? '')?.toLocal();
                final timeStr = requestedAt != null ? DateFormat('MMM d, h:mm a').format(requestedAt) : 'Recent';

                Color statusColor;
                Color statusBg;
                String statusLabel;

                switch (status) {
                  case 'accepted':
                    statusColor = const Color(0xFF059669);
                    statusBg = const Color(0xFFECFDF5);
                    statusLabel = 'Active Session';
                    break;
                  case 'resolved':
                    statusColor = const Color(0xFF2563EB);
                    statusBg = const Color(0xFFEFF6FF);
                    statusLabel = 'Resolved';
                    break;
                  case 'revoked':
                    statusColor = const Color(0xFF64748B);
                    statusBg = const Color(0xFFF1F5F9);
                    statusLabel = 'Revoked';
                    break;
                  case 'declined':
                    statusColor = const Color(0xFFDC2626);
                    statusBg = const Color(0xFFFEF2F2);
                    statusLabel = 'Declined';
                    break;
                  case 'pending':
                  default:
                    statusColor = const Color(0xFFD97706);
                    statusBg = const Color(0xFFFFFBEB);
                    statusLabel = 'Pending Acceptance';
                    break;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                          const Spacer(),
                          Text(
                            '${r['duration_hours'] ?? 2}h window',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () async {
                                await ItAccessService.revokeRequest(r['id'], widget.user.email!);
                                widget.onSessionUpdated();
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r['issue_description'] ?? 'IT Elevation Request',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scope: ${r['access_scope'] ?? 'General'}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
