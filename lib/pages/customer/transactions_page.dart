import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class TransactionsPage extends StatefulWidget {
  final List<dynamic> initialTransactions;

  const TransactionsPage({super.key, required this.initialTransactions});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<dynamic> _transactions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.initialTransactions);
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
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
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
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkGrey, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGrey,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A read-only record of your past and current activities.',
                style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              if (_isLoading && _transactions.isEmpty)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              else if (_transactions.isEmpty)
                _buildEmptyState()
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'No transactions found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkGrey, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your transaction history will appear here\nonce you complete your first booking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx) {
    final status = tx['status'] ?? 'pending';
    final paymentStatus = tx['payment_status'] ?? 'unpaid';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              color: AppTheme.primaryColor.withOpacity(0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx['event_type'] ?? 'Reservation',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGrey,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
            ),
            
            // Card Details
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today_rounded, 'Date', tx['event_date']),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.access_time_rounded, 'Time', tx['start_time']),
                  if (tx['number_of_guests'] != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.people_alt_rounded, 'Guests', '${tx['number_of_guests']} guests'),
                  ],
                  if (tx['_db_table'] == 'reservations') ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.timer_rounded, 'Duration', '${tx['duration_hours']} hours'),
                  ],
                  
                  const Divider(height: 36),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYMENT STATUS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 6),
                          _buildPaymentBadge(paymentStatus),
                        ],
                      ),
                      if (tx['_db_table'] == 'advance_orders' && tx['total_price'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TOTAL PAID',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₱${(tx['total_price'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.successGreen,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Ref: ${tx['id'].toString().substring(0, 8).toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey.withOpacity(0.7), fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
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
        Icon(icon, size: 20, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 14),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey, letterSpacing: 0.3),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkGrey, letterSpacing: -0.2),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
    final isDepositPaid = paymentStatus == 'deposit_paid';
    final color = isPaid
        ? AppTheme.successGreen
        : isDepositPaid
            ? Colors.blue
            : AppTheme.warningOrange;
    final label = isPaid
        ? 'PAID'
        : isDepositPaid
            ? 'DEPOSIT PAID'
            : paymentStatus.toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPaid ? Icons.verified_rounded : Icons.pending_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
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
      default:
        color = AppTheme.mediumGrey;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
