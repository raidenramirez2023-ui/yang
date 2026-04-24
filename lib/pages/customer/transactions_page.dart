import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

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

      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('customer_email', currentUser.email!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(response);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkGrey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
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
      padding: const EdgeInsets.symmetric(vertical: 80),
      width: double.infinity,
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No transactions found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your transaction history will appear here\nonce you complete your first booking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx) {
    final status = tx['status'] ?? 'pending';
    final paymentStatus = tx['payment_status'] ?? 'unpaid';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: AppTheme.cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppTheme.primaryColor.withValues(alpha: 0.03),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx['event_type'] ?? 'Reservation',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
            ),
            
            // Card Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today_rounded, 'Date', tx['event_date']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time_rounded, 'Time', tx['start_time']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.people_alt_rounded, 'Guests', '${tx['number_of_guests']} guests'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.timer_rounded, 'Duration', '${tx['duration_hours']} hours'),
                  
                  const Divider(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYMENT STATUS',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            paymentStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: paymentStatus == 'paid' ? AppTheme.successGreen : AppTheme.warningOrange,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Ref: ${tx['id'].toString().substring(0, 8).toUpperCase()}',
                        style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
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
        Icon(icon, size: 18, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.mediumGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
            textAlign: TextAlign.end,
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
      case 'cancelled':
        color = AppTheme.errorRed;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppTheme.mediumGrey;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
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
}
