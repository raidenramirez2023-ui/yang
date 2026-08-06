import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/refund_service.dart';
import 'package:yang_chow/utils/app_theme.dart';

class RefundManagementPage extends StatefulWidget {
  final bool isFullscreen;
  const RefundManagementPage({super.key, this.isFullscreen = false});

  @override
  State<RefundManagementPage> createState() => _RefundManagementPageState();
}

class _RefundManagementPageState extends State<RefundManagementPage> {
  final RefundService _refundService = RefundService();
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  final List<Map<String, String>> _filterTabs = [
    {'key': 'all', 'label': 'All Refunds'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'approved', 'label': 'Approved'},
    {'key': 'completed', 'label': 'Completed'},
    {'key': 'rejected', 'label': 'Rejected'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Status badge helper ───────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warningOrange;
      case 'approved':
        return AppTheme.infoBlue;
      case 'completed':
        return AppTheme.successGreen;
      case 'rejected':
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _sourceLabel(String sourceTable) {
    switch (sourceTable) {
      case 'orders':
        return 'POS Order';
      case 'reservations':
        return 'Event Reservation';
      case 'advance_orders':
        return 'Advance Order';
      default:
        return sourceTable;
    }
  }

  Color _sourceColor(String sourceTable) {
    switch (sourceTable) {
      case 'orders':
        return const Color(0xFF6366F1); // indigo
      case 'reservations':
        return AppTheme.primaryColor;
      case 'advance_orders':
        return const Color(0xFF0EA5E9); // sky blue
      default:
        return AppTheme.mediumGrey;
    }
  }

  // ── Filter refunds ────────────────────────────────────────
  List<Map<String, dynamic>> _filterRefunds(
      List<Map<String, dynamic>> refunds) {
    var filtered = refunds.where((r) {
      if (_selectedFilter != 'all' &&
          r['status']?.toString().toLowerCase() != _selectedFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (r['customer_name'] ?? '').toString().toLowerCase();
        final email = (r['customer_email'] ?? '').toString().toLowerCase();
        final txId = (r['transaction_id'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            email.contains(query) ||
            txId.contains(query);
      }
      return true;
    }).toList();

    return filtered;
  }

  // ── Approve dialog ────────────────────────────────────────
  void _showApproveDialog(Map<String, dynamic> refund) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
            const SizedBox(width: 10),
            const Text('Approve Refund'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve refund of ${_currencyFormat.format(refund['refund_amount'])} for ${refund['customer_name']}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Admin Notes (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminEmail =
                  Supabase.instance.client.auth.currentUser?.email ??
                      'admin';
              final success = await _refundService.approveRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                adminNotes: notesController.text.isNotEmpty
                    ? notesController.text
                    : null,
              );
              if (mounted) {
                _showSnackBar(
                  success
                      ? 'Refund approved successfully!'
                      : 'Failed to approve refund',
                  success ? Colors.green : Colors.red,
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reject dialog ─────────────────────────────────────────
  void _showRejectDialog(Map<String, dynamic> refund) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppTheme.errorRed),
            const SizedBox(width: 10),
            const Text('Reject Refund'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject refund of ${_currencyFormat.format(refund['refund_amount'])} for ${refund['customer_name']}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (required)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar('Please provide a rejection reason', Colors.orange);
                return;
              }
              Navigator.pop(ctx);
              final adminEmail =
                  Supabase.instance.client.auth.currentUser?.email ??
                      'admin';
              final success = await _refundService.rejectRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                rejectionReason: reasonController.text.trim(),
              );
              if (mounted) {
                _showSnackBar(
                  success
                      ? 'Refund rejected.'
                      : 'Failed to reject refund',
                  success ? Colors.orange : Colors.red,
                );
              }
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Process PayMongo refund ────────────────────────────────
  Future<void> _processPayMongoRefund(Map<String, dynamic> refund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payment_rounded, color: AppTheme.infoBlue),
            const SizedBox(width: 10),
            const Text('Process PayMongo Refund'),
          ],
        ),
        content: Text(
          'This will process a PayMongo refund of ${_currencyFormat.format(refund['refund_amount'])} back to the customer\'s original payment method.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.infoBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Process Refund'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result =
          await _refundService.processPayMongoRefund(refundId: refund['id']);
      if (mounted) {
        _showSnackBar(
          result['success']
              ? 'PayMongo refund processed successfully!'
              : 'PayMongo refund failed: ${result['error']}',
          result['success'] ? Colors.green : Colors.red,
        );
      }
    }
  }

  // ── Mark cash refund as completed ─────────────────────────
  Future<void> _markCashReturned(Map<String, dynamic> refund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.money_rounded, color: AppTheme.successGreen),
            const SizedBox(width: 10),
            const Text('Confirm Cash Returned'),
          ],
        ),
        content: Text(
          'Confirm that ${_currencyFormat.format(refund['refund_amount'])} has been physically returned to ${refund['customer_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminEmail =
          Supabase.instance.client.auth.currentUser?.email ?? 'admin';
      final success = await _refundService.completeManualRefund(
        refundId: refund['id'],
        adminEmail: adminEmail,
      );
      if (mounted) {
        _showSnackBar(
          success
              ? 'Cash refund marked as completed!'
              : 'Failed to complete refund',
          success ? Colors.green : Colors.red,
        );
      }
    }
  }

  // ── Change passcode dialog ────────────────────────────────
  void _showChangePasscodeDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            const Text('Change Refund Passcode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Passcode',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Passcode',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Passcode',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                _showSnackBar('New passcodes do not match', Colors.orange);
                return;
              }
              if (newController.text.isEmpty) {
                _showSnackBar('Passcode cannot be empty', Colors.orange);
                return;
              }
              final isValid = await _refundService
                  .verifyAdminPasscode(currentController.text);
              if (!isValid) {
                if (mounted) {
                  _showSnackBar('Current passcode is incorrect', Colors.red);
                }
                return;
              }
              final success = await _refundService
                  .updateAdminPasscode(newController.text);
              if (mounted) {
                Navigator.pop(ctx);
                _showSnackBar(
                  success
                      ? 'Passcode updated successfully!'
                      : 'Failed to update passcode',
                  success ? Colors.green : Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.adminBackground,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _refundService.refundsStream(),
        builder: (context, snapshot) {
          final allRefunds = snapshot.data ?? [];
          final filteredRefunds = _filterRefunds(allRefunds);

          // Pagination
          final totalPages =
              (filteredRefunds.length / _rowsPerPage).ceil();
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage)
              .clamp(0, filteredRefunds.length);
          final pageRefunds = filteredRefunds.isEmpty
              ? <Map<String, dynamic>>[]
              : filteredRefunds.sublist(startIndex, endIndex);

          return CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Refund Management',
                                  style: AppTheme.sectionHeaderStyle.copyWith(
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage refund requests from customers and POS',
                                  style: TextStyle(
                                    color: AppTheme.mediumGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Change passcode button
                          OutlinedButton.icon(
                            onPressed: _showChangePasscodeDialog,
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text('Change Passcode'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Summary cards ──
                      _buildSummaryCards(allRefunds),
                      const SizedBox(height: 20),

                      // ── Filter tabs ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filterTabs.map((tab) {
                            final isSelected =
                                _selectedFilter == tab['key'];
                            int count = 0;
                            if (tab['key'] == 'all') {
                              count = allRefunds.length;
                            } else {
                              count = allRefunds
                                  .where((r) =>
                                      r['status']?.toString() ==
                                      tab['key'])
                                  .length;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(
                                    '${tab['label']} ($count)'),
                                onSelected: (_) => setState(() {
                                  _selectedFilter = tab['key']!;
                                  _currentPage = 0;
                                }),
                                selectedColor:
                                    AppTheme.primaryColor.withOpacity(0.15),
                                checkmarkColor: AppTheme.primaryColor,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.darkGrey,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Search bar ──
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() {
                          _searchQuery = v;
                          _currentPage = 0;
                        }),
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or transaction ID...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppTheme.mediumGrey),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Refund list ──
              if (snapshot.connectionState == ConnectionState.waiting &&
                  allRefunds.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredRefunds.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'all'
                              ? 'No refund records yet'
                              : 'No ${_selectedFilter} refunds',
                          style: TextStyle(
                              color: AppTheme.mediumGrey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= pageRefunds.length) return null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: _buildRefundCard(pageRefunds[index]),
                      );
                    },
                    childCount: pageRefunds.length,
                  ),
                ),

              // ── Pagination ──
              if (totalPages > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () =>
                                  setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          'Page ${_currentPage + 1} of $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          onPressed: _currentPage < totalPages - 1
                              ? () =>
                                  setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Summary cards ─────────────────────────────────────────
  Widget _buildSummaryCards(List<Map<String, dynamic>> allRefunds) {
    final pending =
        allRefunds.where((r) => r['status'] == 'pending').length;
    final approved =
        allRefunds.where((r) => r['status'] == 'approved').length;
    final completed =
        allRefunds.where((r) => r['status'] == 'completed').length;

    double totalRefunded = 0;
    for (final r in allRefunds) {
      if (r['status'] == 'completed') {
        totalRefunded +=
            (r['refund_amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return Row(
      children: [
        _summaryCard(
          icon: Icons.hourglass_empty_rounded,
          label: 'Pending',
          value: '$pending',
          color: AppTheme.warningOrange,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          icon: Icons.check_circle_outline_rounded,
          label: 'Approved',
          value: '$approved',
          color: AppTheme.infoBlue,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          icon: Icons.verified_rounded,
          label: 'Completed',
          value: '$completed',
          color: AppTheme.successGreen,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Total Refunded',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.mediumGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(totalRefunded),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(label,
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ── Refund card ───────────────────────────────────────────
  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final status = (refund['status'] ?? 'pending').toString();
    final sourceTable = (refund['source_table'] ?? '').toString();
    final refundMethod = (refund['refund_method'] ?? 'cash').toString();
    final amount = (refund['refund_amount'] as num?)?.toDouble() ?? 0;
    final originalAmount =
        (refund['original_amount'] as num?)?.toDouble() ?? 0;
    final requestedAt = refund['requested_at'] != null
        ? DateFormat('MMM dd, yyyy · h:mm a')
            .format(DateTime.parse(refund['requested_at']).toLocal())
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: source badge + status + date ──
            Row(
              children: [
                // Source type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sourceColor(sourceTable).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _sourceLabel(sourceTable),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _sourceColor(sourceTable),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refund method badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: refundMethod == 'paymongo'
                        ? Colors.indigo.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        refundMethod == 'paymongo'
                            ? Icons.credit_card_rounded
                            : Icons.money_rounded,
                        size: 12,
                        color: refundMethod == 'paymongo'
                            ? Colors.indigo
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        refundMethod == 'paymongo' ? 'PayMongo' : 'Cash',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: refundMethod == 'paymongo'
                              ? Colors.indigo
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status),
                          size: 14, color: _statusColor(status)),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Customer info + amounts ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refund['customer_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      if (refund['customer_email'] != null)
                        Text(
                          refund['customer_email'],
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.mediumGrey),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: AppTheme.mediumGrey),
                          const SizedBox(width: 4),
                          Text(requestedAt,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.mediumGrey)),
                        ],
                      ),
                      if (refund['transaction_id'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Transaction #${refund['transaction_id']}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.mediumGrey),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(amount),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      'of ${_currencyFormat.format(originalAmount)}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.mediumGrey),
                    ),
                    Text(
                      '${refund['refund_type']?.toString().toUpperCase() ?? 'N/A'} REFUND',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Reason ──
            if (refund['refund_reason'] != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment_rounded,
                        size: 14, color: AppTheme.mediumGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        refund['refund_reason'],
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.darkGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Admin notes ──
            if (refund['admin_notes'] != null &&
                refund['admin_notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.infoBlue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        size: 14, color: AppTheme.infoBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Admin: ${refund['admin_notes']}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.infoBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Action buttons ──
            if (status == 'pending' || status == 'approved') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending') ...[
                    OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(refund),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(
                            color: AppTheme.errorRed.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(refund),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                  if (status == 'approved') ...[
                    if (refundMethod == 'paymongo')
                      ElevatedButton.icon(
                        onPressed: () => _processPayMongoRefund(refund),
                        icon: const Icon(Icons.credit_card_rounded,
                            size: 16),
                        label: const Text('Process PayMongo Refund'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.infoBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _markCashReturned(refund),
                        icon:
                            const Icon(Icons.money_rounded, size: 16),
                        label: const Text('Mark as Cash Returned'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
