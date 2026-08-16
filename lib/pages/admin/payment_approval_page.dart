import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/ocr_service.dart';

final _moneyFmt = NumberFormat('#,##0.00', 'en_PH');

class PaymentApprovalPage extends StatefulWidget {
  const PaymentApprovalPage({super.key});

  @override
  State<PaymentApprovalPage> createState() => _PaymentApprovalPageState();
}

class _PaymentApprovalPageState extends State<PaymentApprovalPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingPayments = [];
  final ReservationService _reservationService = ReservationService();
  
  // OCR State
  final Map<String, Map<String, dynamic>> _ocrResults = {};
  final Map<String, bool> _analyzingState = {};

  @override
  void initState() {
    super.initState();
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
      
      setState(() {
        _pendingPayments = [...taggedReservations, ...taggedAdvanceOrders];
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
            backgroundColor: Colors.red,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingPayments(); // Refresh list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving payment: $e'),
            backgroundColor: Colors.red,
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
        title: Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for rejecting this payment:'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectPayment(payment['id'], payment['_table'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Reject'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment rejected successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingPayments(); // Refresh list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeReceipt(String paymentId, String imageUrl) async {
    if (_analyzingState[paymentId] == true) return;

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
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('PayMongo Receipt'),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Failed to load receipt image', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
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
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14332E).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFFD9A441), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Approvals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Review and verify customer deposit and full payments',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalPending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Text(
                            '$totalPending Pending',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 10),
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      onPressed: _loadPendingPayments,
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.mediumGrey),
                      tooltip: 'Refresh',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Quick Stats Bar ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildApprovalStatCard(
                    'Awaiting Review',
                    totalPending.toString(),
                    Icons.pending_actions_rounded,
                    const Color(0xFFFEF3C7),
                    const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildApprovalStatCard(
                    'Amount to Verify',
                    '₱${_moneyFmt.format(totalPendingAmount)}',
                    Icons.account_balance_wallet_rounded,
                    const Color(0xFFDCFCE7),
                    const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildApprovalStatCard(
                    'Reservations',
                    reservationCount.toString(),
                    Icons.event_seat_rounded,
                    const Color(0xFFE0F2FE),
                    const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildApprovalStatCard(
                    'Advance Orders',
                    advanceCount.toString(),
                    Icons.fastfood_rounded,
                    const Color(0xFFF3E8FF),
                    const Color(0xFF7E22CE),
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
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                        blurRadius: 20,
                                        spreadRadius: 5 * value,
                                      )
                                    ]
                                  ),
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'FETCHING PAYMENTS...',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    )
                  : _pendingPayments.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPendingPayments,
                          color: AppTheme.primaryColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _pendingPayments.length,
                            itemBuilder: (context, index) {
                              final payment = _pendingPayments[index];
                              return TweenAnimationBuilder<double>(
                                key: ValueKey(payment['id']),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 350 + (index * 80).clamp(0, 500)),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
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
        ),
      ),
    );
  }

  Widget _buildApprovalStatCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    color: AppTheme.mediumGrey,
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
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withValues(alpha: 0.1 * value),
                        blurRadius: 30,
                        spreadRadius: 10 * value,
                      )
                    ]
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: AppTheme.successGreen,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'There are no payments waiting for approval.\nYou can safely relax for now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, BuildContext context) {
    final String table = payment['_table'] ?? 'reservations';
    final bool isAdvanceOrder = table == 'advance_orders';
    final double amountToVerify = (payment['deposit_amount'] as num?)?.toDouble() ?? (payment['total_price'] as num?)?.toDouble() ?? 0.0;
    final double totalAmount = (payment['total_price'] as num?)?.toDouble() ?? amountToVerify;
    final String paymentRef = payment['payment_reference'] ?? 'REF-NOT-SET';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _HoverAnimatedCard(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Transaction Header Bar ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                            ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_bottom_rounded, size: 12, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text(
                            'Awaiting Verification',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Financial Highlight & Reference Banner ────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
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
                                letterSpacing: 0.5,
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
                                    color: Color(0xFF15803D),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isAdvanceOrder ? 'FULL PAYMENT' : (payment['payment_status'] == 'fully_paid' ? 'FULL (100%)' : 'DEPOSIT (50%)'),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
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
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GATEWAY REF NUMBER',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      paymentRef,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Customer & Booking Information Grid ───────────────────────
                _buildCompactDetailGrid(payment, isAdvanceOrder),
                const SizedBox(height: 14),

                // ── Receipt & OCR Actions ────────────────────────────────────
                if (payment['receipt_url'] != null && payment['receipt_url'].toString().isNotEmpty) ...[
                  _buildReceiptActions(payment),
                  const SizedBox(height: 12),
                ],

                // ── OCR Assistant Analysis Panel ─────────────────────────────
                if (_ocrResults.containsKey(payment['id'])) ...[
                  _buildOCRPanel(payment, _ocrResults[payment['id']]!),
                  const SizedBox(height: 14),
                ],

                // ── Action Buttons ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(payment),
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Reject Payment', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        Text(
                          'Run "Auto-Verify" to inspect digital receipt before approval.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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

  Widget _buildCompactDetailGrid(Map<String, dynamic> payment, bool isAdvanceOrder) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  Icons.person_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Email Address',
                  payment['customer_email'] ?? 'N/A',
                  Icons.email_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  isAdvanceOrder ? 'Order Type' : 'Event Type',
                  isAdvanceOrder ? (payment['order_type'] ?? 'N/A') : (payment['event_type'] ?? 'N/A'),
                  isAdvanceOrder ? Icons.fastfood_rounded : Icons.celebration_rounded,
                  isHighlight: true,
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
                  Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Scheduled Time',
                  isAdvanceOrder ? (payment['order_time'] ?? 'N/A') : '${payment['start_time']} (${payment['duration_hours'] ?? 4}h)',
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDetailItem(
                  'Guest PAX',
                  '${payment['number_of_guests'] ?? 1} Guests',
                  Icons.groups_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailItem(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF14332E).withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight ? const Color(0xFF14332E).withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isHighlight ? const Color(0xFFC9922E) : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF0F172A),
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

  Widget _buildReceiptActions(Map<String, dynamic> payment) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _viewReceiptImage(payment['receipt_url'].toString()),
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('View Receipt', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _analyzingState[payment['id']] == true 
                ? null 
                : () => _analyzeReceipt(payment['id'], payment['receipt_url'].toString()),
            icon: _analyzingState[payment['id']] == true 
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner, size: 16),
            label: Text(_analyzingState[payment['id']] == true ? 'Analyzing...' : 'Auto-Verify', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.withValues(alpha: 0.1),
              foregroundColor: Colors.purple,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
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
    
    return _buildActionButton(
      onPressed: enabled ? () => _approvePayment(payment['id'], table) : () {},
      icon: Icons.check_circle_outline,
      label: 'Approve Payment',
      isPrimary: true,
      isDisabled: !enabled,
    );
  }

  Widget _buildOCRPanel(Map<String, dynamic> payment, Map<String, dynamic> ocr) {
    if (ocr['success'] == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 18), const SizedBox(width: 8), Expanded(child: Text('Analysis failed: ${ocr['error']}', style: const TextStyle(fontSize: 12, color: Colors.red)))]),
      );
    }

    final double expectedAmount = (payment['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final double? detectedAmount = ocr['detectedAmount'];
    final bool amountMatches = detectedAmount != null && (detectedAmount - expectedAmount).abs() < 1.0;
    
    final String expectedRef = payment['payment_reference'] ?? '';
    final List<dynamic> detectedRefs = ocr['detectedRefs'] ?? [];
    
    // Smart Matching: Match if any detected ref is part of the internal ref 
    // OR if we found a valid-looking PayMongo/GCash reference (e.g., xlSResj or pay_...)
    final bool refMatches = detectedRefs.isNotEmpty && (
      detectedRefs.any((r) => expectedRef.toLowerCase().contains(r.toString().toLowerCase())) ||
      detectedRefs.any((r) => r.toString().length >= 6) // Most PayMongo/GCash refs are 6+ chars
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
        color: allVerified ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: allVerified ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_search, color: allVerified ? Colors.green : Colors.orange, size: 16),
              const SizedBox(width: 8),
              const Text('OCR Verification Assistant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: allVerified ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$passedChecks/4 Verified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: allVerified ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOCRRow('Amount Detected', detectedAmount != null ? '₱${_moneyFmt.format(detectedAmount)}' : 'Not Found', amountMatches ? Icons.check_circle : (detectedAmount == null ? Icons.help_outline : Icons.warning_amber), amountMatches ? Colors.green : Colors.red),
          _buildOCRRow('Reference ID', detectedRefs.isNotEmpty ? detectedRefs.first.toString() : 'Not Found', refMatches ? Icons.check_circle : Icons.help_outline, refMatches ? Colors.green : Colors.orange),
          _buildOCRRow('Payment ID', detectedPaymentId ?? 'Not Found', paymentIdFound ? Icons.check_circle : Icons.help_outline, paymentIdFound ? Colors.green : Colors.red),
          _buildOCRRow('QRPh Payment Received!', hasQrphReceived ? 'Confirmed' : 'Not Found', hasQrphReceived ? Icons.check_circle : Icons.help_outline, hasQrphReceived ? Colors.green : Colors.red),
          if (!amountMatches && detectedAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚠️ Warning: Amount mismatch (Expected ₱${_moneyFmt.format(expectedAmount)})', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          if (!allVerified)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'All 4 checks must be verified before approving. Make sure the receipt shows a completed payment, not a pending QR code.',
                        style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.w500),
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
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
    bool isDisabled = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      child: isPrimary 
        ? ElevatedButton.icon(
            onPressed: isDisabled ? null : onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled ? Colors.grey.shade300 : AppTheme.successGreen,
              foregroundColor: isDisabled ? Colors.grey.shade500 : Colors.white,
              elevation: isDisabled ? 0 : 4,
              shadowColor: isDisabled ? Colors.transparent : AppTheme.successGreen.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            ),
          )
        : OutlinedButton.icon(
            onPressed: isDisabled ? null : onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDisabled ? Colors.grey.shade500 : Colors.red.shade600,
              side: BorderSide(color: isDisabled ? Colors.grey.shade300 : Colors.red.shade200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            ),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        // ignore: deprecated_member_use
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..scale(_isHovered ? 1.01 : 1.0)
          ..setTranslationRaw(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
