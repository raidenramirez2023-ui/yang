import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Status helpers ────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
        return const Color(0xFF0284C7);
      case 'completed':
        return const Color(0xFF15803D);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'approved':
        return Icons.gpp_good_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
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
        return sourceTable.isNotEmpty ? sourceTable : 'General';
    }
  }

  Color _sourceColor(String sourceTable) {
    switch (sourceTable) {
      case 'orders':
        return const Color(0xFF0284C7);
      case 'reservations':
        return const Color(0xFF7C3AED);
      case 'advance_orders':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _sourceIcon(String sourceTable) {
    switch (sourceTable) {
      case 'orders':
        return Icons.point_of_sale_rounded;
      case 'reservations':
        return Icons.event_rounded;
      case 'advance_orders':
        return Icons.schedule_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  // ── Filter ────────────────────────────────────────────────
  List<Map<String, dynamic>> _filterRefunds(List<Map<String, dynamic>> refunds) {
    var filtered = refunds.where((r) {
      if (_selectedFilter != 'all' && r['status']?.toString().toLowerCase() != _selectedFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (r['customer_name'] ?? '').toString().toLowerCase();
        final email = (r['customer_email'] ?? '').toString().toLowerCase();
        final txId = (r['transaction_id'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || txId.contains(query);
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin';
              final success = await _refundService.approveRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                adminNotes: notesController.text.isNotEmpty ? notesController.text : null,
              );
              if (mounted) {
                _showSnackBar(
                  success ? 'Refund approved successfully!' : 'Failed to approve refund',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin';
              final success = await _refundService.rejectRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                rejectionReason: reasonController.text.trim(),
              );
              if (mounted) {
                _showSnackBar(
                  success ? 'Refund rejected.' : 'Failed to reject refund',
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.infoBlue, foregroundColor: Colors.white),
            child: const Text('Process Refund'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final result = await _refundService.processPayMongoRefund(refundId: refund['id']);
      if (mounted) {
        _showSnackBar(
          result['success'] ? 'PayMongo refund processed successfully!' : 'PayMongo refund failed: ${result['error']}',
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
            Icon(Icons.payments_rounded, color: AppTheme.successGreen),
            const SizedBox(width: 10),
            const Text('Confirm Cash Returned'),
          ],
        ),
        content: Text(
          'Confirm that ${_currencyFormat.format(refund['refund_amount'])} has been physically returned to ${refund['customer_name']}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin';
      final success = await _refundService.completeManualRefund(refundId: refund['id'], adminEmail: adminEmail);
      if (mounted) {
        _showSnackBar(
          success ? 'Cash refund marked as completed!' : 'Failed to complete refund',
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
            Icon(Icons.lock_rounded, color: AppTheme.adminChatButton),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Passcode',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Passcode',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
              final isValid = await _refundService.verifyAdminPasscode(currentController.text);
              if (!isValid) {
                if (mounted) _showSnackBar('Current passcode is incorrect', Colors.red);
                return;
              }
              final success = await _refundService.updateAdminPasscode(newController.text);
              if (mounted) {
                Navigator.pop(ctx);
                _showSnackBar(
                  success ? 'Passcode updated successfully!' : 'Failed to update passcode',
                  success ? Colors.green : Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.adminChatButton, foregroundColor: Colors.white),
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _refundService.refundsStream(),
        builder: (context, snapshot) {
          final allRefunds = snapshot.data ?? [];
          final filteredRefunds = _filterRefunds(allRefunds);
          final totalPages = (filteredRefunds.length / _rowsPerPage).ceil();
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredRefunds.length);
          final pageRefunds = filteredRefunds.isEmpty ? <Map<String, dynamic>>[] : filteredRefunds.sublist(startIndex, endIndex);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Card (Petty Cash style) ──
                      _buildHeader(allRefunds),
                      const SizedBox(height: 20),

                      // ── Analytics Grid ──
                      _buildAnalyticsGrid(allRefunds),
                      const SizedBox(height: 24),

                      // ── Section Title ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Refund Management',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Manage refund requests from customers and POS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Search bar ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _currentPage = 0;
                          }),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search by name, email, or transaction ID...',
                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () => setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    }),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Filter Pills (Petty Cash style) ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterPill('all', 'All Refunds (${allRefunds.length})', Icons.apps_rounded, const Color(0xFF14332E)),
                            _buildFilterPill('pending', 'Pending (${allRefunds.where((r) => r['status'] == 'pending').length})', Icons.hourglass_top_rounded, const Color(0xFFD97706)),
                            _buildFilterPill('approved', 'Approved (${allRefunds.where((r) => r['status'] == 'approved').length})', Icons.gpp_good_rounded, const Color(0xFF0284C7)),
                            _buildFilterPill('completed', 'Completed (${allRefunds.where((r) => r['status'] == 'completed').length})', Icons.verified_rounded, const Color(0xFF15803D)),
                            _buildFilterPill('rejected', 'Rejected (${allRefunds.where((r) => r['status'] == 'rejected').length})', Icons.cancel_rounded, const Color(0xFFDC2626)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Refund list ──
              if (snapshot.connectionState == ConnectionState.waiting && allRefunds.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF14332E))))
              else if (filteredRefunds.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilter == 'all' ? 'No refund records yet' : 'No ${_selectedFilter} refunds',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Refund requests will appear here',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= pageRefunds.length) return null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Page ${_currentPage + 1} of $totalPages',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  // ── Header Card (mirrors Petty Cash Executive Card) ───────
  Widget _buildHeader(List<Map<String, dynamic>> allRefunds) {
    double totalRefunded = 0;
    for (final r in allRefunds) {
      if (r['status'] == 'completed') {
        totalRefunded += (r['refund_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    final pending = allRefunds.where((r) => r['status'] == 'pending').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF142421), Color(0xFF1E3A34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.35), width: 1.2),
      ),
      child: Stack(
        children: [
          // Decorative ambient glows
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD9A441).withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF34C759).withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE6C374), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Refund Management',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFE6C374),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF9500))),
                              const SizedBox(width: 6),
                              Text(
                                '$pending PENDING',
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFFB020), fontWeight: FontWeight.w700, fontSize: 10),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34C759))),
                              const SizedBox(width: 6),
                              Text(
                                'ALL CLEAR',
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF86EFAC), fontWeight: FontWeight.w700, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showChangePasscodeDialog,
                        icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFF94A3B8)),
                        label: Text('Passcode', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'TOTAL REFUNDED',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('₱', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFD9A441), fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(
                    NumberFormat('#,##0.00').format(totalRefunded),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sub-stats row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Color(0xFFE6C374), size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Records', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500)),
                              Text('${allRefunds.length} ${allRefunds.length == 1 ? 'refund' : 'refunds'}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: Color(0xFFFF9500), size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pending Review', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500)),
                              Text('$pending ${pending == 1 ? 'item' : 'items'}', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFFB020), fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Analytics grid (same tile design as Petty Cash) ───────
  Widget _buildAnalyticsGrid(List<Map<String, dynamic>> allRefunds) {
    final pending = allRefunds.where((r) => r['status'] == 'pending').length;
    final approved = allRefunds.where((r) => r['status'] == 'approved').length;
    final completed = allRefunds.where((r) => r['status'] == 'completed').length;
    final rejected = allRefunds.where((r) => r['status'] == 'rejected').length;

    final cards = [
      _buildMetricTile(
        title: 'Pending',
        value: '$pending',
        subtitle: 'Awaiting admin action',
        icon: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFD97706),
        bgTint: const Color(0xFFFEF3C7),
      ),
      _buildMetricTile(
        title: 'Approved',
        value: '$approved',
        subtitle: 'Ready to be processed',
        icon: Icons.gpp_good_rounded,
        iconColor: const Color(0xFF0284C7),
        bgTint: const Color(0xFFE0F2FE),
      ),
      _buildMetricTile(
        title: 'Completed',
        value: '$completed',
        subtitle: 'Funds returned to customer',
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF15803D),
        bgTint: const Color(0xFFDCFCE7),
      ),
      _buildMetricTile(
        title: 'Rejected',
        value: '$rejected',
        subtitle: 'Declined refund requests',
        icon: Icons.cancel_rounded,
        iconColor: const Color(0xFFDC2626),
        bgTint: const Color(0xFFFEE2E2),
      ),
    ];

    return Row(
      children: cards
          .map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: card)))
          .toList(),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: bgTint, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Filter Pill (identical to Petty Cash) ─────────────────
  Widget _buildFilterPill(String key, String label, IconData icon, Color color) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedFilter = key;
          _currentPage = 0;
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0)),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Refund card (Petty Cash card style with left accent bar) ──
  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final status = (refund['status'] ?? 'pending').toString();
    final sourceTable = (refund['source_table'] ?? '').toString();
    final refundMethod = (refund['refund_method'] ?? 'cash').toString();
    final amount = (refund['refund_amount'] as num?)?.toDouble() ?? 0;
    final originalAmount = (refund['original_amount'] as num?)?.toDouble() ?? 0;
    final requestedAt = refund['requested_at'] != null
        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(refund['requested_at']).toLocal())
        : 'N/A';
    final statusColor = _statusColor(status);
    final srcColor = _sourceColor(sourceTable);

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 5, color: statusColor),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top badges row
                      Row(
                        children: [
                          // Source badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: srcColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_sourceIcon(sourceTable), size: 12, color: srcColor),
                                const SizedBox(width: 4),
                                Text(
                                  _sourceLabel(sourceTable),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: srcColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Refund method badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: refundMethod == 'paymongo'
                                  ? Colors.indigo.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  refundMethod == 'paymongo' ? Icons.credit_card_rounded : Icons.payments_rounded,
                                  size: 12,
                                  color: refundMethod == 'paymongo' ? Colors.indigo : Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  refundMethod == 'paymongo' ? 'PayMongo' : 'Cash',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: refundMethod == 'paymongo' ? Colors.indigo : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(status), size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Customer info + original amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  refund['customer_name'] ?? 'Unknown',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (refund['customer_email'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    refund['customer_email'],
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 5),
                                    Text(requestedAt, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                                if (refund['transaction_id'] != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Transaction #${refund['transaction_id']}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ],
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
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD9A441),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'of ${_currencyFormat.format(originalAmount)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${refund['refund_type']?.toString().toUpperCase() ?? 'N/A'} REFUND',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Reason
                      if (refund['refund_reason'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  refund['refund_reason'],
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Admin notes
                      if (refund['admin_notes'] != null && refund['admin_notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppTheme.infoBlue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Admin: ${refund['admin_notes']}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.infoBlue, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Action buttons
                      if (status == 'pending' || status == 'approved') ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (status == 'pending') ...[
                              OutlinedButton.icon(
                                onPressed: () => _showRejectDialog(refund),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: Text('Reject', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(refund),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: Text('Approve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14332E),
                                  foregroundColor: const Color(0xFFE6C374),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                            if (status == 'approved') ...[
                              if (refundMethod == 'paymongo')
                                ElevatedButton.icon(
                                  onPressed: () => _processPayMongoRefund(refund),
                                  icon: const Icon(Icons.credit_card_rounded, size: 16),
                                  label: Text('Process PayMongo Refund', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF14332E),
                                    foregroundColor: const Color(0xFFE6C374),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _markCashReturned(refund),
                                  icon: const Icon(Icons.payments_rounded, size: 16),
                                  label: Text('Mark as Cash Returned', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF14332E),
                                    foregroundColor: const Color(0xFFE6C374),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
