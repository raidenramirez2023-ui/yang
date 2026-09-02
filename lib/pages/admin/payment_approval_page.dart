import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/ocr_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/pages/admin/remaining_balance_tracking_page.dart';

final _moneyFmt = NumberFormat('#,##0.00', 'en_PH');

class PaymentApprovalPage extends StatefulWidget {
  final bool isFullscreen;
  final int initialTab;
  const PaymentApprovalPage({
    super.key,
    this.isFullscreen = false,
    this.initialTab = 0,
  });

  @override
  State<PaymentApprovalPage> createState() => _PaymentApprovalPageState();
}

class _PaymentApprovalPageState extends State<PaymentApprovalPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingPayments = [];
  final ReservationService _reservationService = ReservationService();
  late int _selectedModuleTab;
  int _remainingBalanceCount = 0;
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  
  // OCR State
  final Map<String, Map<String, dynamic>> _ocrResults = {};
  final Map<String, bool> _analyzingState = {};

  // Collapsed items state (default is expanded)
  final Set<String> _collapsedItemIds = {};

  @override
  void initState() {
    super.initState();
    _selectedModuleTab = widget.initialTab;
    MenuService.fetchMenu().then((_) {
      if (mounted) setState(() {});
    });
    _loadPendingPayments();
  }

  Future<void> _loadPendingPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reservations = await _reservationService.getReservationsPendingApproval();
      final advanceOrders = await _reservationService.getAdvanceOrdersPendingApproval();
      
      // Tag each item with its source table
      final taggedReservations = reservations.map((e) => {...e, '_table': 'reservations'}).toList();
      final taggedAdvanceOrders = advanceOrders.map((e) => {...e, '_table': 'advance_orders'}).toList();
      
      // Also fetch remaining balance count for the badge
      int remCount = 0;
      try {
        final remRes = await Supabase.instance.client
            .from('reservations')
            .select('id, total_price, deposit_amount, payment_option, remaining_balance')
            .eq('payment_status', 'deposit_paid')
            .neq('is_archived', true);
        remCount = (remRes as List).where((r) {
          final total = (r['total_price'] as num?)?.toDouble() ?? 0.0;
          final deposit = (r['deposit_amount'] as num?)?.toDouble() ?? 0.0;
          final opt = r['payment_option']?.toString();
          final rem = (r['remaining_balance'] as num?)?.toDouble() ?? (total - deposit);
          return opt != 'full' && (total <= 0 || deposit < total) && rem > 0;
        }).length;
      } catch (_) {}

      setState(() {
        _pendingPayments = [...taggedReservations, ...taggedAdvanceOrders];
        _remainingBalanceCount = remCount;
        // Sort by date, newest first
        _pendingPayments.sort((a, b) => 
          (b['created_at'] as String).compareTo(a['created_at'] as String)
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pending payments: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _approvePayment(String id, String table) async {
    try {
      final success = await _reservationService.approvePendingPayment(
        id: id,
        table: table,
      );

      if (success && mounted) {
        AuditLogService.logActivity(
          action: 'APPROVE',
          module: 'Payments',
          description: 'Approved payment verification for record #$id ($table)',
          entityId: id,
          metadata: {'table': table, 'status': 'approved'},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Payment approved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF14332E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadPendingPayments(); // Refresh list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to approve payment'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving payment: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showRejectDialog(Map<String, dynamic> payment) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text(
              'Reject Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a clear reason for rejecting this payment to inform the customer:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Unclear receipt, amount mismatch, duplicate reference...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                  borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectPayment(payment['id'], payment['_table'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Rejection', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPayment(String id, String table, String reason) async {
    try {
      final success = await _reservationService.rejectPendingPayment(
        id: id,
        table: table,
        reason: reason,
      );

      if (success && mounted) {
        AuditLogService.logActivity(
          action: 'REJECT',
          module: 'Payments',
          description: 'Rejected payment verification for record #$id ($table). Reason: $reason',
          entityId: id,
          metadata: {'table': table, 'status': 'rejected', 'reason': reason},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment rejected'),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadPendingPayments(); // Refresh list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to reject payment'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting payment: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _analyzeReceipt(String paymentId, String imageUrl) async {
    if (imageUrl.isEmpty) return;

    setState(() {
      _analyzingState[paymentId] = true;
    });

    try {
      final results = await OcrService.analyzeReceipt(imageUrl);
      setState(() {
        _ocrResults[paymentId] = results;
      });
    } catch (e) {
      debugPrint('Analysis Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _analyzingState[paymentId] = false;
        });
      }
    }
  }

  void _viewReceiptImage(String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Digital Payment Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF14332E),
                foregroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      receiptUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 16),
                              Text('Failed to load receipt image', style: TextStyle(color: Color(0xFF64748B))),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF14332E)),
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    // Stats calculations
    final totalPending = _pendingPayments.length;
    final totalPendingAmount = _pendingPayments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['deposit_amount'] as num?)?.toDouble() ?? (p['total_price'] as num?)?.toDouble() ?? 0.0),
    );
    final advanceCount = _pendingPayments.where((p) => p['_table'] == 'advance_orders').length;
    final reservationCount = _pendingPayments.where((p) => p['_table'] == 'reservations').length;

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Premium Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.isFullscreen || Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      tooltip: 'Back to POS',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFFD9A441), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          _selectedModuleTab == 0
                              ? 'Review and verify customer deposit and full payments'
                              : 'Monitor outstanding balances, collect via GCash QR, and inspect settlement history',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedModuleTab == 0 && totalPending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Text(
                            '$totalPending Pending',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 10),
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      onPressed: () {
                        _loadPendingPayments();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
                      tooltip: 'Refresh',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Segmented Switcher for Approvals vs Remaining Balances ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModuleTabButton(
                      title: 'Payment Approvals',
                      subtitle: 'Verification & OCR',
                      icon: Icons.verified_user_rounded,
                      badgeCount: totalPending,
                      isSelected: _selectedModuleTab == 0,
                      onTap: () => setState(() => _selectedModuleTab = 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildModuleTabButton(
                      title: 'Remaining Balances',
                      subtitle: 'Outstanding & Settlements',
                      icon: Icons.account_balance_wallet_rounded,
                      badgeCount: _remainingBalanceCount,
                      isSelected: _selectedModuleTab == 1,
                      onTap: () => setState(() => _selectedModuleTab = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Active Tab Content ──
            Expanded(
              child: _selectedModuleTab == 0
                  ? _buildApprovalsBody(
                      context: context,
                      totalPending: totalPending,
                      totalPendingAmount: totalPendingAmount,
                      advanceCount: advanceCount,
                      reservationCount: reservationCount,
                    )
                  : RemainingBalanceTrackingPage(
                      isEmbedded: true,
                      isFullscreen: widget.isFullscreen,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleTabButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required int badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF14332E).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFFD9A441) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsBody({
    required BuildContext context,
    required int totalPending,
    required double totalPendingAmount,
    required int advanceCount,
    required int reservationCount,
  }) {
    // Pagination calculations (10 items per page)
    final totalItems = _pendingPayments.length;
    final totalPages = totalItems > 0 ? (totalItems / _itemsPerPage).ceil() : 1;
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < totalItems)
        ? startIndex + _itemsPerPage
        : totalItems;

    final paginatedPayments = totalItems > 0
        ? _pendingPayments.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cohesive Stats Bar (Realistic & User-Friendly) ───────────────
        if (!ResponsiveUtils.isDesktop(context))
          SizedBox(
            height: 66,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                SizedBox(
                  width: 145,
                  child: _buildApprovalStatCard(
                    'Awaiting Review',
                    totalPending.toString(),
                    Icons.pending_actions_rounded,
                    const Color(0xFFFFFBEB),
                    const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 175,
                  child: _buildApprovalStatCard(
                    'Amount to Verify',
                    '₱${_moneyFmt.format(totalPendingAmount)}',
                    Icons.account_balance_wallet_rounded,
                    const Color(0xFFECFDF5),
                    const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildApprovalStatCard(
                    'Reservations',
                    reservationCount.toString(),
                    Icons.event_seat_rounded,
                    const Color(0xFFF1F5F9),
                    const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 145,
                  child: _buildApprovalStatCard(
                    'Advance Orders',
                    advanceCount.toString(),
                    Icons.fastfood_rounded,
                    const Color(0xFFF1F5F9),
                    const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildApprovalStatCard(
                  'Awaiting Review',
                  totalPending.toString(),
                  Icons.pending_actions_rounded,
                  const Color(0xFFFFFBEB),
                  const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildApprovalStatCard(
                  'Amount to Verify',
                  '₱${_moneyFmt.format(totalPendingAmount)}',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFECFDF5),
                  const Color(0xFF047857),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildApprovalStatCard(
                  'Reservations',
                  reservationCount.toString(),
                  Icons.event_seat_rounded,
                  const Color(0xFFF1F5F9),
                  const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildApprovalStatCard(
                  'Advance Orders',
                  advanceCount.toString(),
                  Icons.fastfood_rounded,
                  const Color(0xFFF1F5F9),
                  const Color(0xFF475569),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // ── Main Content ─────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Color(0xFF14332E)),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Loading pending payments...',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : _pendingPayments.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadPendingPayments,
                      color: const Color(0xFF14332E),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: paginatedPayments.length + (totalItems > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == paginatedPayments.length) {
                            return _buildApprovalPagination(
                              totalItems: totalItems,
                              currentPage: _currentPage,
                              totalPages: totalPages,
                              onPageChanged: (newPage) {
                                setState(() {
                                  _currentPage = newPage;
                                });
                              },
                            );
                          }
                          final payment = paginatedPayments[index];
                          return TweenAnimationBuilder<double>(
                            key: ValueKey(payment['id']),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 250 + (index * 40).clamp(0, 300)),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 15 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildPaymentCard(payment, context),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildApprovalPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (currentPage * _itemsPerPage < totalItems)
        ? currentPage * _itemsPerPage
        : totalItems;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startItem–$endItem of $totalItems pending payments',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14332E),
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prev Button
                InkWell(
                  onTap: currentPage > 1
                      ? () {
                          onPageChanged(currentPage - 1);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prev',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Page Number Buttons with smart ellipsis window
                ...List.generate(totalPages, (index) {
                  final pageNum = index + 1;
                  if (totalPages > 5) {
                    if (pageNum != 1 &&
                        pageNum != totalPages &&
                        (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                      if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '…',
                            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  }

                  final isSelected = pageNum == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          onPageChanged(pageNum);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD9A441).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$pageNum',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF14332E) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),

                // Next Button
                InkWell(
                  onTap: currentPage < totalPages
                      ? () {
                          onPageChanged(currentPage + 1);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ],
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

  Widget _buildApprovalStatCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are no payments waiting for approval.\nYou can safely relax for now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, BuildContext context) {
    final String table = payment['_table'] ?? 'reservations';
    final bool isAdvanceOrder = table == 'advance_orders';
    final double totalAmount = (payment['total_price'] as num?)?.toDouble() ?? 0.0;
    final double rawDeposit = (payment['deposit_amount'] as num?)?.toDouble() ?? (payment['downpayment_amount'] as num?)?.toDouble() ?? 0.0;
    final bool isFullPayment = isAdvanceOrder ||
        payment['payment_option'] == 'full' ||
        payment['payment_status'] == 'fully_paid' ||
        payment['payment_status'] == 'paid' ||
        (totalAmount > 0 && rawDeposit >= totalAmount);
    final double amountToVerify = isFullPayment
        ? (totalAmount > 0 ? totalAmount : (rawDeposit > 0 ? rawDeposit : 0.0))
        : (rawDeposit > 0 ? rawDeposit : totalAmount);
    final String paymentRef = payment['payment_reference'] ?? 'REF-NOT-SET';
    final isMobile = ResponsiveUtils.isMobile(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _HoverAnimatedCard(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Transaction Header Bar ────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Authentic GCash Brand Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007DFE), // Official GCash Blue
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007DFE).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 13),
                              SizedBox(width: 5),
                              Text(
                                'GCash / PayMongo',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Type Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            isAdvanceOrder ? 'ADVANCE ORDER' : 'BANQUET RESERVATION',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_bottom_rounded, size: 12, color: Color(0xFFB45309)),
                          SizedBox(width: 4),
                          Text(
                            'Awaiting Verification',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Financial Highlight & Reference Banner ────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PAYMENT AMOUNT TO VERIFY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₱${_moneyFmt.format(amountToVerify)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF14332E),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    isFullPayment ? (isAdvanceOrder ? 'FULL PAYMENT' : 'FULL (100%)') : 'DEPOSIT (50%)',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total Order Price: ₱${_moneyFmt.format(totalAmount)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            _buildReferenceBox(paymentRef),
                          ],
                        )
                      : Row(
                          children: [
                            // Amount to approve
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PAYMENT AMOUNT TO VERIFY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₱${_moneyFmt.format(amountToVerify)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF14332E),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Text(
                                          isFullPayment ? (isAdvanceOrder ? 'FULL PAYMENT' : 'FULL (100%)') : 'DEPOSIT (50%)',
                                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Total Order Price: ₱${_moneyFmt.format(totalAmount)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            // Reference code pill
                            Expanded(
                              flex: 2,
                              child: _buildReferenceBox(paymentRef),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // ── Customer & Booking Information Grid ───────────────────────
                _buildCompactDetailGrid(payment, isAdvanceOrder),
                const SizedBox(height: 12),

                // ── Order Items & Quotation Breakdown ─────────────────────────
                _buildItemsAndQuotationBreakdown(payment, isAdvanceOrder),
                const SizedBox(height: 12),

                // ── Receipt & OCR Actions (Lively & Brand-Aligned) ─────────────
                if (payment['receipt_url'] != null && payment['receipt_url'].toString().isNotEmpty) ...[
                  _buildReceiptActions(payment),
                  const SizedBox(height: 10),
                ],

                // ── OCR Assistant Analysis Panel ─────────────────────────────
                if (_ocrResults.containsKey(payment['id'])) ...[
                  _buildOCRPanel(payment, _ocrResults[payment['id']]!),
                  const SizedBox(height: 12),
                ],

                // ── Action Buttons (Vibrant, Clear, and Balanced) ─────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(payment),
                        icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Reject Payment',
                          style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildApproveButton(payment, table),
                  ],
                ),

                // Guidance note
                if (!_canApprovePayment(payment))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 5),
                        const Text(
                          'Run "Auto-Verify" to inspect digital receipt before approval.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceBox(String paymentRef) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GATEWAY REF NUMBER',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  paymentRef,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: paymentRef));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Reference copied to clipboard'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy Reference',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailGrid(Map<String, dynamic> payment, bool isAdvanceOrder) {
    final isMobile = ResponsiveUtils.isMobile(context);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildCompactDetailItem(
                    'Customer Name',
                    payment['customer_name'] ?? 'N/A',
                    Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactDetailItem(
                    isAdvanceOrder ? 'Order Type' : 'Event Type',
                    isAdvanceOrder ? (payment['order_type'] ?? 'N/A') : (payment['event_type'] ?? 'N/A'),
                    isAdvanceOrder ? Icons.fastfood_outlined : Icons.celebration_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactDetailItem(
              'Email Address',
              payment['customer_email'] ?? 'N/A',
              Icons.mail_outline_rounded,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactDetailItem(
                    'Date & Time',
                    '${(isAdvanceOrder ? payment['order_date'] : payment['event_date']) ?? 'N/A'} ${(isAdvanceOrder ? payment['order_time'] : payment['start_time']) ?? ''}',
                    Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactDetailItem(
                    'Guest PAX',
                    '${payment['number_of_guests'] ?? 1} Guests',
                    Icons.groups_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCompactDetailItem(
                  'Customer Name',
                  payment['customer_name'] ?? 'N/A',
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Email Address',
                  payment['customer_email'] ?? 'N/A',
                  Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  isAdvanceOrder ? 'Order Type' : 'Event Type',
                  isAdvanceOrder ? (payment['order_type'] ?? 'N/A') : (payment['event_type'] ?? 'N/A'),
                  isAdvanceOrder ? Icons.fastfood_outlined : Icons.celebration_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactDetailItem(
                  'Scheduled Date',
                  (isAdvanceOrder ? payment['order_date'] : payment['event_date']) ?? 'N/A',
                  Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Scheduled Time',
                  isAdvanceOrder ? (payment['order_time'] ?? 'N/A') : '${payment['start_time']} (${payment['duration_hours'] ?? 4}h)',
                  Icons.schedule_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Guest PAX',
                  '${payment['number_of_guests'] ?? 1} Guests',
                  Icons.groups_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _getMenuItemPrice(String menuName) {
    final menu = MenuService.getMenu();
    final cleanSearch = menuName.trim().toLowerCase();
    for (var category in menu.values) {
      for (var item in category) {
        if (item.name.trim().toLowerCase() == cleanSearch) {
          return item.price;
        }
      }
    }
    return null;
  }

  Widget _buildItemsAndQuotationBreakdown(Map<String, dynamic> payment, bool isAdvanceOrder) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final paymentId = (payment['id'] ?? '').toString();
    final isCollapsed = _collapsedItemIds.contains(paymentId);

    // Parse selected menu items
    final dynamic rawMenu = payment['selected_menu_items'] ?? payment['items'] ?? payment['menu_items'];
    final List<Map<String, dynamic>> parsedItems = [];

    if (rawMenu is Map) {
      rawMenu.forEach((key, val) {
        final qty = val is num ? val.toInt() : (int.tryParse(val.toString()) ?? 1);
        if (qty > 0) {
          final unitPrice = _getMenuItemPrice(key.toString()) ?? 0.0;
          parsedItems.add({
            'name': key.toString(),
            'qty': qty,
            'unit_price': unitPrice,
            'total_price': unitPrice * qty,
          });
        }
      });
    } else if (rawMenu is List) {
      for (final item in rawMenu) {
        if (item is Map) {
          final name = (item['name'] ?? item['title'] ?? item['item_name'] ?? 'Item').toString();
          final qty = (item['quantity'] ?? item['qty'] ?? 1) is num
              ? (item['quantity'] ?? item['qty'] ?? 1).toInt()
              : (int.tryParse((item['quantity'] ?? item['qty'] ?? 1).toString()) ?? 1);
          final rawPrice = item['price'] ?? item['unit_price'] ?? _getMenuItemPrice(name) ?? 0.0;
          final unitPrice = double.tryParse(rawPrice.toString()) ?? 0.0;
          parsedItems.add({
            'name': name,
            'qty': qty,
            'unit_price': unitPrice,
            'total_price': (item['total_price'] != null)
                ? (double.tryParse(item['total_price'].toString()) ?? (unitPrice * qty))
                : (unitPrice * qty),
          });
        } else if (item is String && item.isNotEmpty) {
          final unitPrice = _getMenuItemPrice(item) ?? 0.0;
          parsedItems.add({
            'name': item,
            'qty': 1,
            'unit_price': unitPrice,
            'total_price': unitPrice,
          });
        }
      }
    }

    final int totalItemQty = parsedItems.fold<int>(0, (sum, i) => sum + (i['qty'] as int));

    // Financials for Event Reservation
    final rawTotal = payment['total_price'] ?? payment['total_amount'] ?? payment['price'] ?? 0;
    final totalAmount = double.tryParse(rawTotal.toString()) ?? 0.0;
    final rawDeposit = payment['downpayment_amount'] ?? payment['deposit_amount'] ?? (totalAmount * 0.5);
    final depositAmount = double.tryParse(rawDeposit.toString()) ?? 0.0;
    final bool isFullPayment = isAdvanceOrder ||
        payment['payment_option'] == 'full' ||
        payment['payment_status'] == 'fully_paid' ||
        payment['payment_status'] == 'paid' ||
        (totalAmount > 0 && depositAmount >= totalAmount);
    final remainingBalance = isFullPayment ? 0.0 : ((totalAmount > depositAmount) ? (totalAmount - depositAmount) : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle Bar
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedItemIds.remove(paymentId);
                } else {
                  _collapsedItemIds.add(paymentId);
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isAdvanceOrder ? Icons.restaurant_menu_rounded : Icons.lunch_dining_rounded,
                    size: 16,
                    color: const Color(0xFF14332E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAdvanceOrder ? 'ORDERED MENU ITEMS' : 'CATERING MENU INCLUSIONS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${parsedItems.length} item${parsedItems.length == 1 ? '' : 's'}${totalItemQty > parsedItems.length ? ' ($totalItemQty pcs)' : ''}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isCollapsed ? 'View Details' : 'Hide Details',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    size: 16,
                    color: const Color(0xFF0284C7),
                  ),
                ],
              ),
            ),
          ),

          if (!isCollapsed) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Menu Items Listing
            if (parsedItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  isAdvanceOrder
                      ? 'No specific menu items recorded for this order.'
                      : 'Standard banquet catering package inclusions apply.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: parsedItems.map((item) {
                    final name = item['name'] as String;
                    final qty = item['qty'] as int;
                    final unitPrice = item['unit_price'] as double;
                    final itemTotal = item['total_price'] as double;

                    if (isAdvanceOrder) {
                      return _buildAdvanceOrderItemRow(name, qty, unitPrice, itemTotal, isMobile);
                    } else {
                      // Event reservation inclusions
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (qty > 1) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'Qty: $qty',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text(
                                'Package Inclusion',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }).toList(),
                ),
              ),

            // Event Reservation Quotation Financial Breakdown Box (No admin notes)
            if (!isAdvanceOrder) ...[
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.request_quote_outlined, size: 14, color: Color(0xFF0F766E)),
                        SizedBox(width: 6),
                        Text(
                          'QUOTATION FINANCIAL BREAKDOWN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Quoted Price:',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₱${_moneyFmt.format(totalAmount)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              isFullPayment ? 'Full Payment (100%):' : 'Deposit Required (50%):',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '[Amount to Verify]',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF047857), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Text(
                          '₱${_moneyFmt.format(isFullPayment ? totalAmount : depositAmount)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                    if (!isFullPayment) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Remaining Balance:',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₱${_moneyFmt.format(remainingBalance)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAdvanceOrderItemRow(String name, int qty, double unitPrice, double itemTotal, bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF14332E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (unitPrice > 0)
                    Text(
                      '₱${_moneyFmt.format(unitPrice)} each',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '× $qty',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              itemTotal > 0 ? '₱${_moneyFmt.format(itemTotal)}' : '—',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF14332E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '× $qty',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 85,
            child: Text(
              unitPrice > 0 ? '@ ₱${_moneyFmt.format(unitPrice)}' : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 95,
            child: Text(
              itemTotal > 0 ? '₱${_moneyFmt.format(itemTotal)}' : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptActions(Map<String, dynamic> payment) {
    final bool isAnalyzing = _analyzingState[payment['id']] == true;

    return Row(
      children: [
        // View Receipt Button (Warm Gold Accent)
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => _viewReceiptImage(payment['receipt_url'].toString()),
              icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFB45309)),
              label: const Text(
                'View Receipt',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFBEB),
                side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Auto-Verify Button (Smart Emerald Accent)
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: isAnalyzing 
                  ? null 
                  : () => _analyzeReceipt(payment['id'], payment['receipt_url'].toString()),
              icon: isAnalyzing 
                  ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)))
                  : const Icon(Icons.document_scanner_rounded, size: 16, color: Color(0xFF047857)),
              label: Text(
                isAnalyzing ? 'Analyzing...' : 'Auto-Verify',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _canApprovePayment(Map<String, dynamic> payment) {
    final paymentId = payment['id'].toString();
    if (!_ocrResults.containsKey(paymentId)) return false;
    
    final ocr = _ocrResults[paymentId]!;
    if (ocr['success'] == false) return false;

    final double expectedAmount = (payment['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final double? detectedAmount = ocr['detectedAmount'];
    final bool amountMatches = detectedAmount != null && (detectedAmount - expectedAmount).abs() < 1.0;
    
    final String expectedRef = payment['payment_reference'] ?? '';
    final List<dynamic> detectedRefs = ocr['detectedRefs'] ?? [];
    
    final bool refMatches = detectedRefs.isNotEmpty && (
      detectedRefs.any((r) => expectedRef.toLowerCase().contains(r.toString().toLowerCase())) ||
      detectedRefs.any((r) => r.toString().length >= 6)
    );

    // Check Payment ID (pay_xxx format)
    final String? detectedPaymentId = ocr['detectedPaymentId'];
    final bool paymentIdFound = detectedPaymentId != null && detectedPaymentId.isNotEmpty;

    // Check QRPh Payment Received! confirmation text
    final bool hasQrphReceived = ocr['hasQrphReceived'] == true;

    // Must have verified ALL FOUR: amount, reference, payment ID, and QRPh received
    return amountMatches && refMatches && paymentIdFound && hasQrphReceived;
  }

  Widget _buildApproveButton(Map<String, dynamic> payment, String table) {
    final bool enabled = _canApprovePayment(payment);
    
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => _approvePayment(payment['id'], table) : null,
        icon: Icon(
          enabled ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
          size: 17,
          color: enabled ? Colors.white : const Color(0xFF94A3B8),
        ),
        label: Text(
          'Approve Payment',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: enabled ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
          elevation: enabled ? 2 : 0,
          shadowColor: enabled ? const Color(0xFF14332E).withValues(alpha: 0.3) : Colors.transparent,
          side: BorderSide(
            color: enabled ? Colors.transparent : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildOCRPanel(Map<String, dynamic> payment, Map<String, dynamic> ocr) {
    if (ocr['success'] == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Analysis failed: ${ocr['error']}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final double expectedAmount = (payment['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final double? detectedAmount = ocr['detectedAmount'];
    final bool amountMatches = detectedAmount != null && (detectedAmount - expectedAmount).abs() < 1.0;
    
    final String expectedRef = payment['payment_reference'] ?? '';
    final List<dynamic> detectedRefs = ocr['detectedRefs'] ?? [];
    
    final bool refMatches = detectedRefs.isNotEmpty && (
      detectedRefs.any((r) => expectedRef.toLowerCase().contains(r.toString().toLowerCase())) ||
      detectedRefs.any((r) => r.toString().length >= 6)
    );

    // Payment ID verification (pay_xxx format)
    final String? detectedPaymentId = ocr['detectedPaymentId'];
    final bool paymentIdFound = detectedPaymentId != null && detectedPaymentId.isNotEmpty;

    // QRPh Payment Received! confirmation
    final bool hasQrphReceived = ocr['hasQrphReceived'] == true;

    // Count how many checks passed
    final int passedChecks = [
      amountMatches,
      refMatches,
      paymentIdFound,
      hasQrphReceived,
    ].where((v) => v).length;
    final bool allVerified = passedChecks == 4;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allVerified ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner_rounded,
                color: allVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'OCR Verification Summary',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: allVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allVerified ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  '$passedChecks/4 Verified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: allVerified ? const Color(0xFF059669) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOCRRow(
            'Amount Detected',
            detectedAmount != null ? '₱${_moneyFmt.format(detectedAmount)}' : 'Not Found',
            amountMatches ? Icons.check_circle_rounded : (detectedAmount == null ? Icons.help_outline_rounded : Icons.warning_amber_rounded),
            amountMatches ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          _buildOCRRow(
            'Reference ID',
            detectedRefs.isNotEmpty ? detectedRefs.first.toString() : 'Not Found',
            refMatches ? Icons.check_circle_rounded : Icons.help_outline_rounded,
            refMatches ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          _buildOCRRow(
            'Payment ID',
            detectedPaymentId ?? 'Not Found',
            paymentIdFound ? Icons.check_circle_rounded : Icons.help_outline_rounded,
            paymentIdFound ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          _buildOCRRow(
            'QRPh Payment Received!',
            hasQrphReceived ? 'Confirmed' : 'Not Found',
            hasQrphReceived ? Icons.check_circle_rounded : Icons.help_outline_rounded,
            hasQrphReceived ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          if (!amountMatches && detectedAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⚠️ Amount mismatch (Expected: ₱${_moneyFmt.format(expectedAmount)})',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
              ),
            ),
          if (!allVerified)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'All 4 checks must be verified before approving. Make sure the receipt shows a completed payment.',
                        style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
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

  Widget _buildOCRRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _HoverAnimatedCard extends StatefulWidget {
  final Widget child;

  const _HoverAnimatedCard({required this.child});

  @override
  State<_HoverAnimatedCard> createState() => _HoverAnimatedCardState();
}

class _HoverAnimatedCardState extends State<_HoverAnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        // ignore: deprecated_member_use
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..scale(_isHovered ? 1.005 : 1.0)
          ..setTranslationRaw(0.0, _isHovered ? -2.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
