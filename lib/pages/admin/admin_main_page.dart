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

import 'package:yang_chow/widgets/admin_chat_modal.dart';



import 'package:yang_chow/services/notification_service.dart';




import 'package:yang_chow/utils/url_sync_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
    _loadPendingPaymentCount();
    _loadPendingReservationCount();
    _loadRemainingBalanceCount();
    _loadPendingRefundCount();

    // Start periodic refresh for counts (reduced frequency to prevent database issues)
    _countRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadPendingPaymentCount();
      _loadPendingReservationCount();
      _loadRemainingBalanceCount();
      _loadPendingRefundCount();
    });

    NotificationService.startStockMonitoring();

    // Listen to admin notifications in real-time to show floating toast banner and update sidebar badges
    _adminNotifsSubscription = NotificationService.getAdminOnlyNotificationsStream().listen((notifs) {
      if (!mounted) return;
      _loadPendingPaymentCount();
      _loadPendingReservationCount();
      _loadRemainingBalanceCount();
      _loadPendingRefundCount();

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

  Future<void> _checkUserRole() async {



    final isAdmin = await RoleHelper.isAdmin();







    if (!isAdmin && mounted) {



      Navigator.pushReplacementNamed(context, '/staff-dashboard');



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
          .eq('status', 'pending_admin_approval')
          .inFilter('payment_status', ['deposit_paid', 'fully_paid'])
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
      child: layout,
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

                          child: _pages[_selectedIndex],

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
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444), // Uniform Red
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
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

          Padding(

            padding: const EdgeInsets.all(24),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: AppTheme.adminActiveSidebarAccent,

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: const Icon(

                    Icons.restaurant,

                    color: Colors.white,

                    size: 24,

                  ),

                ),

                const SizedBox(width: 12),

                const Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'AdminPanel',

                      style: TextStyle(

                        fontWeight: FontWeight.bold,

                        fontSize: 18,

                        color: Colors.white,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),



          const SizedBox(height: 8),

          Expanded(

            child: ListView.builder(

              padding: const EdgeInsets.symmetric(horizontal: 16),

              itemCount: _pageTitles.length,

              itemBuilder: (context, index) {

                final isSelected = _selectedIndex == index;

                return Padding(

                  padding: const EdgeInsets.only(bottom: 4),

                  child: Material(

                    color: isSelected

                        ? AppTheme.activeSidebarItemBackground

                        : Colors.transparent,

                    borderRadius: BorderRadius.circular(12),

                    child: InkWell(

                      borderRadius: BorderRadius.circular(12),

                      onTap: () {

                        _onSelectTab(index);

                        // Refresh count when switching to Payment Management
                        if (_pageTitles[index] == 'Payment Management') {
                          // Reset count to 0 when admin views payment management (mark as seen)
                          if (mounted) {
                            setState(() {
                              _pendingPaymentCount = 0;
                              _remainingBalanceCount = 0;
                            });
                          }
                        }

                        // Refresh count when switching to Reservations
                        if (_pageTitles[index] == 'Reservations') {
                          // Reset count to 0 when admin views reservations (mark as seen)
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

                      },

                      child: Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 16,

                          vertical: 12,

                        ),

                        child: Row(

                          children: [

                            Icon(

                              _pageIcons[index],

                              size: 20,

                              color: isSelected

                                  ? AppTheme.activeSidebarAccent

                                  : AppTheme.sidebarInactiveIcon,

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Text(

                                _pageTitles[index],

                                style: TextStyle(

                                  fontWeight: isSelected

                                      ? FontWeight.w600

                                      : FontWeight.w500,

                                  color: isSelected

                                      ? AppTheme.activeSidebarAccent

                                      : AppTheme.sidebarInactiveText,

                                ),

                              ),

                            ),

                            // Add badge for Reservations
                            if (_pageTitles[index] == 'Reservations' && _pendingReservationCount > 0)
                              _buildNavBadge(_pendingReservationCount),

                            // Add badge for Payment Management (combined Approvals & Balances)
                            if (_pageTitles[index] == 'Payment Management' && (_pendingPaymentCount + _remainingBalanceCount) > 0)
                              _buildNavBadge(_pendingPaymentCount + _remainingBalanceCount),

                            // Add badge for Refunds & Reschedules
                            if ((_pageTitles[index] == 'Refunds & Reschedules' || _pageTitles[index] == 'Refund Management') && _pendingRefundCount > 0)
                              _buildNavBadge(_pendingRefundCount),
                          ],

                        ),

                      ),

                    ),

                  ),

                );

              },

            ),

          ),

          const Divider(height: 1, color: AppTheme.cardBorder),



          ListTile(

            onTap: () => _showLogoutDialog(context),

            leading: const Icon(Icons.logout, color: Colors.redAccent),

            title: const Text(

              'Logout',

              style: TextStyle(

                color: Colors.redAccent,

                fontWeight: FontWeight.w500,

              ),

            ),

          ),



          const SizedBox(height: 12),

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
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            _pageTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.adminPrimaryText,
            ),
          ),
          const Spacer(),
          _buildStaffDelegationToggle(),
          const SizedBox(width: 14),
          _buildAdminNotificationIcon(),
          const SizedBox(width: 8),
          const SizedBox(width: 16),
          Row(
            children: [
              Container(height: 32, width: 1, color: AppTheme.cardBorder),

              const SizedBox(width: 24),

              Column(

                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Text(

                    currentUser?.email?.split('@')[0] ?? 'Admin',

                    style: const TextStyle(

                      fontWeight: FontWeight.w600,

                      color: AppTheme.adminPrimaryText,

                      fontSize: 14,

                    ),

                  ),

                  const Text(

                    'Admin',

                    style: TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText),

                  ),

                ],

              ),

              const SizedBox(width: 12),

              CircleAvatar(

                radius: 18,

                backgroundColor: AppTheme.adminPricingBackground,

                child: const Icon(Icons.person, color: AppTheme.adminChatButton),

              ),

              const SizedBox(width: 8),

              const Icon(

                Icons.keyboard_arrow_down,

                color: AppTheme.adminSecondaryText,

                size: 20,

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

            _pages[_selectedIndex],

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
            _pages[_selectedIndex],
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



      title: Row(



        mainAxisSize: MainAxisSize.min,



        children: [



          Container(



            padding: const EdgeInsets.all(6),



            decoration: BoxDecoration(



              color: AppTheme.adminChatButton,



              borderRadius: BorderRadius.circular(8),



            ),



            child: const Icon(Icons.restaurant, size: 16, color: Colors.white),



          ),



          const SizedBox(width: 8),



          const Text(



            'AdminPanel',



            style: TextStyle(



              color: AppTheme.adminPrimaryText,



              fontSize: 16,



              fontWeight: FontWeight.bold,



            ),



          ),



        ],



      ),



      leading: Builder(



        builder: (context) => IconButton(



          icon: const Icon(Icons.menu, color: AppTheme.adminSecondaryText),



          onPressed: () => Scaffold.of(context).openDrawer(),



          tooltip: 'Menu',



        ),



      ),



      actions: [



        IconButton(



          icon: const Icon(Icons.logout, color: AppTheme.adminSecondaryText),



          tooltip: 'Logout',



          onPressed: () => _showLogoutDialog(context),



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



      backgroundColor: Colors.white,



      child: Column(



        children: [



          DrawerHeader(



            margin: EdgeInsets.zero,



            padding: const EdgeInsets.all(24),



            decoration: const BoxDecoration(



              color: Colors.white,



              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),



            ),



            child: Row(



              children: [



                Container(



                  padding: const EdgeInsets.all(8),



                  decoration: BoxDecoration(



                    color: AppTheme.adminChatButton,



                    borderRadius: BorderRadius.circular(12),



                  ),



                  child: const Icon(



                    Icons.restaurant,



                    color: Colors.white,



                    size: 24,



                  ),



                ),



                const SizedBox(width: 12),



                const Column(



                  mainAxisAlignment: MainAxisAlignment.center,



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      'AdminPanel',



                      style: TextStyle(



                        fontWeight: FontWeight.bold,



                        fontSize: 18,



                        color: AppTheme.adminPrimaryText,



                      ),



                    ),



                  ],



                ),



              ],



            ),



          ),



          Expanded(



            child: ListView.builder(



              padding: const EdgeInsets.all(16),



              itemCount: _pageTitles.length,



              itemBuilder: (context, index) {



                final isSelected = _selectedIndex == index;



                return Padding(



                  padding: const EdgeInsets.only(bottom: 4),



                  child: Material(



                    color: isSelected



                        ? AppTheme.adminChatButton



                        : Colors.transparent,



                    borderRadius: BorderRadius.circular(12),



                    child: InkWell(



                      borderRadius: BorderRadius.circular(12),



                      onTap: () {
                        setState(() => _selectedIndex = index);

                        // Refresh count when switching to Payment Management
                        if (_pageTitles[index] == 'Payment Management') {
                          // Reset count to 0 when admin views payment management (mark as seen)
                          if (mounted) {
                            setState(() {
                              _pendingPaymentCount = 0;
                              _remainingBalanceCount = 0;
                            });
                          }
                        }

                        // Refresh count when switching to Reservations
                        if (_pageTitles[index] == 'Reservations') {
                          // Reset count to 0 when admin views reservations (mark as seen)
                          if (mounted) {
                            setState(() {
                              _pendingReservationCount = 0;
                            });
                          }
                        }

                        Navigator.pop(context);
                      },

                      child: Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 16,

                          vertical: 12,

                        ),

                        child: Row(

                          children: [

                            Icon(

                              _pageIcons[index],

                              size: 20,

                              color: isSelected

                                  ? Colors.white

                                  : AppTheme.adminSecondaryText,

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Text(

                                _pageTitles[index],

                                style: TextStyle(

                                  fontWeight: isSelected

                                      ? FontWeight.w600

                                      : FontWeight.w500,

                                  color: isSelected

                                      ? Colors.white

                                      : AppTheme.adminSecondaryText,

                                ),

                              ),

                            ),

                            // Add badge for Reservations
                            if (_pageTitles[index] == 'Reservations' && _pendingReservationCount > 0)
                              _buildNavBadge(_pendingReservationCount),

                            // Add badge for Payment Management (combined Approvals & Balances)
                            if (_pageTitles[index] == 'Payment Management' && (_pendingPaymentCount + _remainingBalanceCount) > 0)
                              _buildNavBadge(_pendingPaymentCount + _remainingBalanceCount),

                            // Add badge for Refunds & Reschedules
                            if ((_pageTitles[index] == 'Refunds & Reschedules' || _pageTitles[index] == 'Refund Management') && _pendingRefundCount > 0)
                              _buildNavBadge(_pendingRefundCount),
                          ],

                        ),

                      ),



                    ),



                  ),



                );



              },



            ),



          ),



          const Divider(height: 1, color: AppTheme.cardBorder),



          ListTile(

            leading: const Icon(Icons.logout, color: Colors.redAccent),

            title: const Text(

              'Logout',

              style: TextStyle(color: Colors.redAccent),

            ),

            onTap: () {

              Navigator.pop(context);

              _showLogoutDialog(context);

            },

          ),



          const SizedBox(height: 16),



        ],



      ),



    );



  }







  Widget _buildBottomNavigationBar() {



    return BottomNavigationBar(



      currentIndex: _selectedIndex,



      onTap: (index) {



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

    // FIXED at top: will NEVER disappear until Admin clicks 'VIEW'
    _showAdminTopToast(
      duration: null,
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




