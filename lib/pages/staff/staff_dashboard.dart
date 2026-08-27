import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/pages/staff/staff_order_history_page.dart';
import 'package:yang_chow/pages/admin/refund_management_page.dart';
import 'package:yang_chow/pages/admin/admin_reservations_page.dart';
import 'package:yang_chow/pages/admin/payment_approval_page.dart';
import 'package:yang_chow/pages/admin/remaining_balance_tracking_page.dart';
import 'package:yang_chow/services/notification_service.dart';

import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';
import 'package:yang_chow/widgets/qr_scanner_dialog.dart';
import 'package:yang_chow/services/offline_pos_service.dart';
import 'package:intl/intl.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _userName = 'Staff';
  bool _isLoading = true;
  bool _isDelegationActive = false;

  // Realtime badge counts matching Admin Side
  int _pendingReservationCount = 0;
  int _pendingPaymentCount = 0;
  int _remainingBalanceCount = 0;
  int _pendingRefundCount = 0;
  Timer? _countRefreshTimer;
  StreamSubscription? _adminNotifsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadAllCounts();
    _loadDelegationStatus();

    // Periodic refresh for badges and delegation status (every 1 minute)
    _countRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadAllCounts();
      _loadDelegationStatus();
    });

    // Realtime notification updates to immediately refresh badges
    _adminNotifsSubscription = NotificationService.getAdminOnlyNotificationsStream().listen((_) {
      if (mounted) {
        _loadAllCounts();
        _loadDelegationStatus();
      }
    });
  }

  Future<bool> _loadDelegationStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'staff_delegation_mode')
          .maybeSingle();
      final active = response != null &&
          (response['setting_value']?.toString().toLowerCase() == 'true' ||
              response['setting_value']?.toString() == '1');
      if (mounted && _isDelegationActive != active) {
        setState(() {
          _isDelegationActive = active;
        });
      }
      return active;
    } catch (e) {
      debugPrint('[Staff] Error loading delegation status: $e');
      return _isDelegationActive;
    }
  }

  void _showAdminDutyLockDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Admin is on Duty',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access to $featureName is currently managed by Admin on duty.',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'During Admin rest days, Admin will turn ON "Rest Day Mode" from the Admin Dashboard to automatically unlock transaction approvals for the staff counter.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFD9A441),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countRefreshTimer?.cancel();
    _adminNotifsSubscription?.cancel();
    super.dispose();
  }

  void _loadAllCounts() {
    _loadPendingReservationCount();
    _loadPendingPaymentCount();
    _loadRemainingBalanceCount();
    _loadPendingRefundCount();
  }

  Future<void> _loadPendingPaymentCount() async {
    try {
      final supabase = Supabase.instance.client;
      final countResponse = await supabase
          .from('reservations')
          .select('id')
          .eq('status', 'pending_admin_approval')
          .inFilter('payment_status', ['deposit_paid', 'fully_paid'])
          .eq('is_archived', false);
      if (mounted) {
        setState(() {
          _pendingPaymentCount = (countResponse as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff pending payment count: $e');
    }
  }

  Future<void> _loadPendingReservationCount() async {
    try {
      final supabase = Supabase.instance.client;
      final countResponse = await supabase
          .from('reservations')
          .select('id')
          .eq('is_archived', false)
          .eq('status', 'pending');
      if (mounted) {
        setState(() {
          _pendingReservationCount = (countResponse as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff pending reservation count: $e');
    }
  }

  Future<void> _loadRemainingBalanceCount() async {
    try {
      final supabase = Supabase.instance.client;
      final reservationsCount = await supabase
          .from('reservations')
          .select('id')
          .eq('payment_status', 'deposit_paid')
          .neq('is_archived', true);
      if (mounted) {
        setState(() {
          _remainingBalanceCount = (reservationsCount as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff remaining balance count: $e');
    }
  }

  Future<void> _loadPendingRefundCount() async {
    try {
      final supabase = Supabase.instance.client;
      int refundsCount = 0;
      try {
        final refundRes = await supabase
            .from('refunds')
            .select('id')
            .eq('status', 'pending');
        refundsCount = (refundRes as List).length;
      } catch (_) {}

      int reschedulesCount = 0;
      try {
        final rescheduleRes = await supabase
            .from('reschedule_requests')
            .select('id')
            .eq('status', 'pending');
        reschedulesCount = (rescheduleRes as List).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _pendingRefundCount = refundsCount + reschedulesCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff refund count: $e');
    }
  }

  Widget _buildNavBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444), // Uniform Red (Exact same as Admin side)
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
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int get _totalOperationsBadgeCount =>
      _pendingReservationCount +
      _pendingPaymentCount +
      _remainingBalanceCount +
      _pendingRefundCount;

  Widget _buildOperationsDropdownButton() {
    return AnimatedTapScale(
      onTap: () => _showOperationsModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF5EEAD4).withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F766E).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.layers_rounded,
              color: Color(0xFF5EEAD4),
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              'Operations',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
            if (_totalOperationsBadgeCount > 0)
              _buildNavBadge(_totalOperationsBadgeCount),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white70,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  void _showOperationsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF334155),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.layers_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations Hub',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _isDelegationActive
                              ? '🟢 Rest Day Mode: Staff Authorized'
                              : '🔒 Admin on Duty (View & Process rules apply)',
                          style: TextStyle(
                            color: _isDelegationActive
                                ? const Color(0xFF34D399)
                                : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),

              // Item 1: Reservations
              _buildOperationsMenuItem(
                ctx: ctx,
                title: 'Event Reservations',
                subtitle: 'Manage bookings, quotations & scheduling',
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF2DD4BF),
                badgeCount: _pendingReservationCount,
                onTap: () async {
                  Navigator.pop(ctx);
                  final isAllowed = await _loadDelegationStatus();
                  if (!isAllowed) {
                    _showAdminDutyLockDialog('Event Reservations');
                    return;
                  }
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AdminReservationsPage(isFullscreen: true),
                    ),
                  );
                  _loadAllCounts();
                },
              ),

              const SizedBox(height: 8),

              // Item 2: Approvals
              _buildOperationsMenuItem(
                ctx: ctx,
                title: 'Payment Approvals',
                subtitle: 'Verify GCash & bank transfer payment slips',
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF818CF8),
                badgeCount: _pendingPaymentCount,
                onTap: () async {
                  Navigator.pop(ctx);
                  final isAllowed = await _loadDelegationStatus();
                  if (!isAllowed) {
                    _showAdminDutyLockDialog('Payment Approvals');
                    return;
                  }
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PaymentApprovalPage(isFullscreen: true),
                    ),
                  );
                  _loadAllCounts();
                },
              ),

              const SizedBox(height: 8),

              // Item 3: Balances
              _buildOperationsMenuItem(
                ctx: ctx,
                title: 'Remaining Balances',
                subtitle: 'Track 50% downpayments & collect balance',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF38BDF8),
                badgeCount: _remainingBalanceCount,
                onTap: () async {
                  Navigator.pop(ctx);
                  final isAllowed = await _loadDelegationStatus();
                  if (!isAllowed) {
                    _showAdminDutyLockDialog('Remaining Balances');
                    return;
                  }
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RemainingBalanceTrackingPage(
                        isFullscreen: true,
                      ),
                    ),
                  );
                  _loadAllCounts();
                },
              ),

              const SizedBox(height: 8),

              // Item 4: Refunds
              _buildOperationsMenuItem(
                ctx: ctx,
                title: 'Refunds & Reschedules',
                subtitle: 'Process customer refund & date change requests',
                icon: Icons.currency_exchange_rounded,
                iconColor: const Color(0xFFFBBF24),
                badgeCount: _pendingRefundCount,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RefundManagementPage(
                        isFullscreen: true,
                        todayOnly: true,
                      ),
                    ),
                  );
                  _loadAllCounts();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationsMenuItem({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFF334155),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                _buildNavBadge(badgeCount),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email != null) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('firstname, lastname')
            .eq('email', user!.email!)
            .maybeSingle();

        if (userResponse != null) {
          final firstName = userResponse['firstname']?.toString() ?? '';
          final lastName = userResponse['lastname']?.toString() ?? '';
          
          // Use email prefix if firstname is "Customer" or empty, or if both names are empty
          if (firstName.isNotEmpty && lastName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = '$firstName $lastName';
            });
          } else if (firstName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = firstName;
            });
          } else {
            setState(() {
              _userName = user.email!.split('@')[0];
            });
          }
        } else {
          setState(() {
            _userName = user.email!.split('@')[0];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0C241F),
                Color(0xFF14332E),
                Color(0xFF1B453D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.warmGold.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1C18).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // ── Logo & Terminal Title ──
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Color(0xFFD9A441),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YANG CHOW RESTAURANT',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD9A441),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Staff POS Terminal',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // ── Push all actions to the right side ──
                  const Spacer(),

                  // ── Offline Mode & Sync Status (Katabi ng Scan Pass) ──
                  _buildTopOfflineSyncBadge(),
                  const SizedBox(width: 8),

                  if (_isDelegationActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF34D399), width: 1.1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.beach_access_rounded, color: Color(0xFF34D399), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Rest Day Mode: Active',
                            style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // ── Scan Guest Pass QR Button ──
                  AnimatedTapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      QrScannerDialog.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF15803D), Color(0xFF166534)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF86EFAC).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF15803D).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Scan Pass',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Operations Hub Dropdown Button (Groups Reservations, Approvals, Balances, Refunds) ──
                  _buildOperationsDropdownButton(),
                  const SizedBox(width: 6),

                  // ── Order History Button ──
                  AnimatedTapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StaffOrderHistoryPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'History',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Staff Profile Badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD9A441), width: 1.2),
                            color: const Color(0xFF14332E),
                          ),
                          child: const Center(
                            child: Icon(Icons.person, color: Color(0xFFD9A441), size: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isLoading
                            ? const SizedBox(
                                width: 30,
                                height: 10,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white24,
                                  color: Color(0xFFD9A441),
                                ),
                              )
                            : Text(
                                _userName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Logout Button ──
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 20),
                    tooltip: 'Logout',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Row(
                            children: [
                              const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm Logout',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          content: Text(
                            'Are you sure you want to end your POS session and logout?',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await Supabase.instance.client.auth.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context, '/staff-login');
                                }
                              },
                              child: Text(
                                'Logout',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }

  // ignore: unused_element
  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {
    NotificationService.markAllAsRead('', forAdmin: true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
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
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        child: Icon(
                          _getIconForAction(n['action_type']),
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _getNotificationTitle(n),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getNotificationSubtitle(n),
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

  String _getNotificationTitle(Map<String, dynamic> n) {
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
      case 'paid':
        return 'Payment Received';
      case 'updated':
        return 'Reservation Modified';
      default:
        return 'Activity Alert';
    }
  }

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Kitchen has requested stock: ${n['event_type']}';
    }
    if (n['action_type'] == 'stock_alert') {
      return n['event_type'] ?? 'Stock Alert';
    }
    if (n['action_type'] == 'pos_order') {
      return 'POS staff have order please process';
    }
    return '${n['actor_name'] ?? 'System'} ${n['action_type']} reservation for ${n['event_type'] ?? 'Event'}';
  }

  bool _isSyncingTop = false;

  Widget _buildTopOfflineSyncBadge() {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflinePosService().isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflinePosService().pendingOrdersCountNotifier,
          builder: (context, pendingCount, _) {
            final isOffline = !isOnline;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Pill: only shown when OFFLINE (online is the normal/expected state)
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB45309), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFD97706),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'OFFLINE MODE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Sync Button (if has pending) ──
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  AnimatedTapScale(
                    onTap: _isSyncingTop
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            setState(() => _isSyncingTop = true);
                            final res = await OfflinePosService().syncPendingOrders();
                            if (mounted) {
                              setState(() => _isSyncingTop = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.errorMessage != null
                                      ? 'Sync notice: ${res.errorMessage}'
                                      : 'Synced ${res.syncedCount} offline orders!'),
                                  backgroundColor: res.failedCount == 0 ? Colors.green : Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF93C5FD).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSyncingTop)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.sync_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            _isSyncingTop ? 'Syncing...' : 'Sync Now ($pendingCount)',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}