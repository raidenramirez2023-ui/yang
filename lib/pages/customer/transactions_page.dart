import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

class TransactionsPage extends StatefulWidget {
  final List<dynamic> initialTransactions;

  const TransactionsPage({super.key, required this.initialTransactions});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<dynamic> _transactions;
  bool _isLoading = false;
  Timer? _pollingTimer;
  final _fmt = NumberFormat('#,##0.00', 'en_PH');

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.initialTransactions);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTransactions() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final results = await Future.wait([
        Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
      ]);

      final reservations = List<Map<String, dynamic>>.from(results[0]).map((r) {
        return {...r, '_db_table': 'reservations'};
      }).toList();

      final advanceOrders = List<Map<String, dynamic>>.from(results[1]).where((o) {
        // Only show advance orders that have been paid
        final ps = o['payment_status']?.toString() ?? '';
        return ps == 'paid' || ps == 'fully_paid';
      }).map((o) {
        return {
          ...o,
          'event_type': 'Advance Order (${o['order_type']})',
          'event_date': o['order_date'],
          'start_time': o['order_time'],
          'duration_hours': 0,
          '_db_table': 'advance_orders',
        };
      }).toList();

      final combined = [...reservations, ...advanceOrders];
      combined.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toUtc().toIso8601String());
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _transactions = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh transactions'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        leading: AnimatedTapScale(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Transactions & Order Tracking',
          style: GoogleFonts.lora(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 20, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Orders & Activity',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGrey,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track live status, past orders, and reservation records.',
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              if (_isLoading && _transactions.isEmpty)
                Column(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: AppShimmer(width: double.infinity, height: 160, borderRadius: 20),
                  )),
                )
              else if (_transactions.isEmpty)
                const EmptyStateCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions found',
                  description: 'Your order and reservation activity will appear here live once placed.',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    return _buildTransactionCard(context, tx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx) {
    final status = tx['status']?.toString() ?? 'pending';
    final kitchenStatus = tx['kitchen_status']?.toString() ?? status;
    final paymentStatus = tx['payment_status']?.toString() ?? 'unpaid';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder, width: 1.2), // Light warm gray border #E5E0D2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: #16302A Deep Forest Green
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppTheme.forestGreen, // #16302A
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.warmGold, // #E8B84B Warm Gold icon container
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tx['_db_table'] == 'advance_orders' ? Icons.fastfood_rounded : Icons.event_seat_rounded,
                            size: 16,
                            color: AppTheme.darkBrownText, // #412402 Dark brown icon
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tx['event_type'] ?? 'Reservation',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.priceBadgeText, // #F5F1E6 Off-white
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
            ),

            // Live Order Stepper
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: OrderStatusStepper(status: kitchenStatus),
            ),
            
            // Card Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today_rounded, 'Date', tx['event_date']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time_rounded, 'Time', tx['start_time']),
                  if (tx['number_of_guests'] != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.people_alt_rounded, 'Guests', '${tx['number_of_guests']} guests'),
                  ],
                  if (tx['_db_table'] == 'reservations' && tx['duration_hours'] != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.timer_rounded, 'Duration', '${tx['duration_hours']} hours'),
                  ],
                  
                  const Divider(height: 28, thickness: 1, color: AppTheme.cardBorder),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENT STATUS',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 4),
                          _buildPaymentBadge(paymentStatus, isAdvanceOrder: tx['_db_table'] == 'advance_orders'),
                        ],
                      ),
                      if (tx['_db_table'] == 'advance_orders' && tx['total_price'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TOTAL PAID',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${(tx['total_price'] as num).toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.forestGreen, // #16302A Deep forest green
                              ),
                            ),
                          ],
                        )
                      else if (tx['id'] != null)
                        Text(
                          'Ref: ${tx['id'].toString().substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mediumGrey, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),                  // ── Remaining Balance + Pay Button ───────────────────────
                  if (tx['_db_table'] == 'reservations' && paymentStatus == 'deposit_paid') ...() {
                    final totalPrice = (tx['total_price'] as num?)?.toDouble() ?? 0.0;
                    final depositAmount = (tx['deposit_amount'] as num?)?.toDouble() ?? 0.0;
                    final remaining = (tx['remaining_balance'] as num?)?.toDouble() ?? (totalPrice - depositAmount);
                    if (remaining > 0) {
                      return [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Remaining Balance',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFEA580C)),
                                      ),
                                      Text(
                                        '₱${_fmt.format(remaining)}',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                'Due',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEA580C)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _payRemainingBalance(
                              reservationId: tx['id'].toString(),
                              remaining: remaining,
                              eventType: tx['event_type']?.toString() ?? 'Reservation',
                            ),
                            icon: const Icon(Icons.payment_rounded, size: 16),
                            label: Text(
                              'Pay ₱${_fmt.format(remaining)} via GCash/PayMongo',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ];
                    }
                    return <Widget>[];
                  }(),

                  // ── Fully Settled: Receipt Button ───────────────────────
                  if (tx['_db_table'] == 'reservations' && paymentStatus == 'fully_paid') ...() {
                    final receiptUrl = tx['receipt_url']?.toString();
                    return [
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reservation fully settled — ₱0.00 remaining balance',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (receiptUrl != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(receiptUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF16302A)),
                            label: Text(
                              'View Official Receipt (PDF)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16302A),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFF16302A), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ];
                  }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.forestGreen),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkGrey),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBadge(String paymentStatus, {bool isAdvanceOrder = false}) {
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final color = isPaid
        ? AppTheme.successGreen
        : isDepositPaid
            ? AppTheme.infoBlue
            : AppTheme.warningOrange;
    final label = isPaid
        ? 'PAID'
        : isDepositPaid
            ? (isAdvanceOrder ? 'FULL PAID' : 'DEPOSIT PAID')
            : paymentStatus.toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPaid ? Icons.verified_rounded : Icons.pending_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        color = AppTheme.warningOrange;
        icon = Icons.pending_rounded;
        break;
      case 'confirmed':
        color = AppTheme.successGreen;
        icon = Icons.check_circle_rounded;
        break;
      case 'paid':
      case 'fully_paid':
        color = AppTheme.successGreen;
        icon = Icons.verified_rounded;
        break;
      case 'cancelled':
        color = AppTheme.errorRed;
        icon = Icons.cancel_rounded;
        break;
      case 'no_show':
        color = const Color(0xFFEA580C);
        icon = Icons.person_off_rounded;
        break;
      default:
        color = AppTheme.mediumGrey;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }


  // ── PayMongo Remaining Balance Self-Service ──────────────────────────

  Future<void> _payRemainingBalance({
    required String reservationId,
    required double remaining,
    required String eventType,
  }) async {
    // Show creating link dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            const SizedBox(width: 16),
            const Expanded(child: Text('Creating payment link...')),
          ],
        ),
      ),
    );

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final customerName = currentUser?.userMetadata?['name'] ?? currentUser?.email?.split('@')[0] ?? 'Customer';

      final response = await PayMongoService.createPaymentLink(
        amount: remaining,
        description: 'Remaining Balance — $eventType',
        metadata: {
          'source': 'remaining_balance_self_service',
          'reservation_id': reservationId,
          'customer_name': customerName,
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'] as String;
        final linkId = response['linkId'] as String?;

        // Save link to reservation for tracking
        try {
          await Supabase.instance.client.from('reservations').update({
            'balance_link_id': linkId,
            'balance_link_url': checkoutUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', reservationId);
        } catch (e) {
          debugPrint('Warning: could not save balance link to DB: $e');
        }

        // Open checkout in browser
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

        // Show waiting dialog and start polling
        if (mounted) {
          _showWaitingForPaymentDialog(
            remaining: remaining,
            onCancel: () {
              _pollingTimer?.cancel();
            },
          );
          if (linkId != null) {
            _startPolling(
              linkId: linkId,
              reservationId: reservationId,
              remaining: remaining,
            );
          }
        }
      } else {
        throw Exception('No checkout URL returned');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showWaitingForPaymentDialog({
    required double remaining,
    required VoidCallback onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF0EA5E9)),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for Payment...',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                '₱${_fmt.format(remaining)}',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete payment in the GCash/PayMongo page that just opened.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mediumGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startPolling({
    required String linkId,
    required String reservationId,
    required double remaining,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await PayMongoService.retrievePaymentLink(linkId);
        if (result['isPaid'] == true) {
          timer.cancel();
          if (mounted) Navigator.of(context).pop(); // close waiting dialog

          // Update reservation to fully_paid
          final svc = ReservationService();
          await svc.updatePaymentStatus(
            id: reservationId,
            paymentStatus: 'fully_paid',
            table: 'reservations',
            paymentAmount: null,
            paymentReference: 'PayMongo-Balance',
          );

          // Refresh transactions list
          await _refreshTransactions();

          // Show success
          if (mounted) _showPaymentSuccessDialog(remaining);
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  void _showPaymentSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.successGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Received!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${_fmt.format(amount)} remaining balance successfully paid.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Your reservation is now fully paid ✅',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
