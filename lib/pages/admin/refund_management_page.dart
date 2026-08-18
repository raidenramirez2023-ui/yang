import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/services/refund_service.dart';
import 'package:yang_chow/services/reschedule_service.dart';
import 'package:yang_chow/utils/app_theme.dart';

class RefundManagementPage extends StatefulWidget {
  final bool isFullscreen;
  /// When true, only shows refunds from today (for Staff POS Dashboard use).
  final bool todayOnly;
  const RefundManagementPage({super.key, this.isFullscreen = false, this.todayOnly = false});

  @override
  State<RefundManagementPage> createState() => _RefundManagementPageState();
}

class _RefundManagementPageState extends State<RefundManagementPage> {
  final RefundService _refundService = RefundService();
  final RescheduleService _rescheduleService = RescheduleService();
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rescheduleSearchController = TextEditingController();

  int _selectedMainTab = 0; // 0: Refunds, 1: Reschedule Requests
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 0;

  String _rescheduleFilter = 'all';
  String _rescheduleSearchQuery = '';
  int _rescheduleCurrentPage = 0;
  final int _rowsPerPage = 10;

  Stream<List<Map<String, dynamic>>> _ordersStream() {
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // ── Top Toast Notification Overlay ──
  OverlayEntry? _currentRefundTopToastEntry;
  Timer? _refundTopToastTimer;

  void _dismissRefundTopToast() {
    _refundTopToastTimer?.cancel();
    _refundTopToastTimer = null;
    _currentRefundTopToastEntry?.remove();
    _currentRefundTopToastEntry = null;
  }

  void _showTopToast({
    required Widget content,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    _dismissRefundTopToast();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _RefundTopToastWidget(
        onDismiss: () {
          if (_currentRefundTopToastEntry == entry) {
            _dismissRefundTopToast();
          }
        },
        duration: duration,
        child: content,
      ),
    );

    _currentRefundTopToastEntry = entry;
    overlay.insert(entry);

    _refundTopToastTimer = Timer(duration, () {
      if (_currentRefundTopToastEntry == entry) {
        _dismissRefundTopToast();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rescheduleSearchController.dispose();
    _dismissRefundTopToast();
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
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    var filtered = refunds.where((r) {
      // ── Today-only gate (Staff POS mode) ──────────────────
      if (widget.todayOnly) {
        final created = r['created_at']?.toString() ?? '';
        if (!created.startsWith(todayStr)) {
          return false;
        }
      }
      // ── Status filter ────────────────────────────────────
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

  List<Map<String, dynamic>> _filterReschedules(List<Map<String, dynamic>> requests) {
    var filtered = requests.where((r) {
      if (_rescheduleFilter != 'all' && r['status']?.toString().toLowerCase() != _rescheduleFilter) {
        return false;
      }
      if (_rescheduleSearchQuery.isNotEmpty) {
        final query = _rescheduleSearchQuery.toLowerCase();
        final name = (r['customer_name'] ?? '').toString().toLowerCase();
        final email = (r['customer_email'] ?? '').toString().toLowerCase();
        final phone = (r['customer_phone'] ?? '').toString().toLowerCase();
        final reason = (r['reason'] ?? '').toString().toLowerCase();
        final resId = (r['reservation_id'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || phone.contains(query) || reason.contains(query) || resId.contains(query);
      }
      return true;
    }).toList();
    return filtered;
  }

  // ── Approve Reschedule dialog ─────────────────────────────
  void _showApproveRescheduleDialog(Map<String, dynamic> request) {
    final notesController = TextEditingController();
    final customerName = request['customer_name'] ?? 'Customer';
    final newDate = request['new_date'] ?? '';
    final newTime = request['new_time'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
            const SizedBox(width: 10),
            Text(
              'Approve Reschedule',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm rescheduling reservation for $customerName to $newDate at $newTime?',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Admin Notes (optional)',
                hintText: 'e.g., Table assigned, confirmed with customer',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin';
              final success = await _rescheduleService.approveReschedule(
                requestId: request['id'].toString(),
                reservationId: request['reservation_id'].toString(),
                adminEmail: adminEmail,
                newDate: request['new_date'].toString(),
                newTime: request['new_time'].toString(),
                newDuration: (request['new_duration'] as num?)?.toInt(),
                newGuests: (request['new_guests'] as num?)?.toInt(),
                adminNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                customerEmail: request['customer_email']?.toString(),
                customerName: customerName,
              );
              if (mounted) {
                _showSnackBar(
                  success ? 'Reschedule approved successfully! Schedule updated.' : 'Failed to approve reschedule',
                  success ? Colors.green : Colors.red,
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: Text('Approve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reject Reschedule dialog ──────────────────────────────
  void _showRejectRescheduleDialog(Map<String, dynamic> request) {
    final reasonController = TextEditingController();
    final customerName = request['customer_name'] ?? 'Customer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Text(
              'Reject Reschedule',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject reschedule request for $customerName?',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (required)',
                hintText: 'e.g., Fully booked on requested date/time',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar('Please provide a rejection reason', Colors.orange);
                return;
              }
              Navigator.pop(ctx);
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin';
              final success = await _rescheduleService.rejectReschedule(
                requestId: request['id'].toString(),
                reservationId: request['reservation_id'].toString(),
                adminEmail: adminEmail,
                rejectionReason: reasonController.text.trim(),
                customerEmail: request['customer_email']?.toString(),
                customerName: customerName,
              );
              if (mounted) {
                _showSnackBar(
                  success ? 'Reschedule request rejected.' : 'Failed to reject reschedule',
                  success ? Colors.orange : Colors.red,
                );
              }
            },
            icon: const Icon(Icons.close, size: 18),
            label: Text('Reject Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
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

    final isGreen = color == Colors.green ||
        color == const Color(0xFF15803D) ||
        color == const Color(0xFF10B981) ||
        color == const Color(0xFF059669);
    final isRed = color == Colors.red ||
        color == const Color(0xFFDC2626) ||
        color == const Color(0xFFEF4444);
    final isOrange = color == Colors.orange ||
        color == const Color(0xFFD97706) ||
        color == const Color(0xFFF59E0B);

    final IconData iconData = isGreen
        ? Icons.check_circle_rounded
        : (isRed
            ? Icons.error_rounded
            : (isOrange ? Icons.warning_amber_rounded : Icons.info_rounded));

    final Color bgColor = isGreen
        ? const Color(0xFF0F2E23)
        : (isRed
            ? const Color(0xFF3B1219)
            : (isOrange ? const Color(0xFF382305) : const Color(0xFF1E293B)));

    final Color borderColor = isGreen
        ? const Color(0xFF10B981)
        : (isRed
            ? const Color(0xFFEF4444)
            : (isOrange ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)));

    final Color iconColor = isGreen
        ? const Color(0xFF34D399)
        : (isRed
            ? const Color(0xFFF87171)
            : (isOrange ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA)));

    _showTopToast(
      duration: const Duration(seconds: 4),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _refundService.refundsStream(),
        builder: (context, refundSnapshot) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _ordersStream(),
            builder: (context, orderSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _rescheduleService.rescheduleRequestsStream(),
                builder: (context, rescheduleSnapshot) {
                  final rawRefunds = refundSnapshot.data ?? [];
                  final rawOrders = orderSnapshot.data ?? [];
                  final rawReschedules = rescheduleSnapshot.data ?? [];
                  final now = DateTime.now();
                  final todayStr = DateFormat('yyyy-MM-dd').format(now);

                  final allRefunds = widget.todayOnly
                      ? rawRefunds.where((r) {
                          final created = r['created_at']?.toString() ?? '';
                          return created.startsWith(todayStr);
                        }).toList()
                      : rawRefunds;

                  final todayOrders = rawOrders.where((o) {
                    final created = o['created_at']?.toString() ?? '';
                    return created.startsWith(todayStr);
                  }).toList();

                  double currentOrdersTotal = 0.0;
                  final relevantOrders = widget.todayOnly ? todayOrders : rawOrders;
                  for (final o in relevantOrders) {
                    currentOrdersTotal += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
                  }

                  final pendingRefundsCount = allRefunds.where((r) => r['status'] == 'pending').length;
                  final pendingReschedulesCount = rawReschedules.where((r) => r['status'] == 'pending').length;

                  // ── Refund Filtering & Pagination ──
                  final filteredRefunds = _filterRefunds(allRefunds);
                  final totalRefundPages = (filteredRefunds.length / _rowsPerPage).ceil();
                  final refundStartIndex = _currentPage * _rowsPerPage;
                  final refundEndIndex = (refundStartIndex + _rowsPerPage).clamp(0, filteredRefunds.length);
                  final pageRefunds = filteredRefunds.isEmpty
                      ? <Map<String, dynamic>>[]
                      : filteredRefunds.sublist(refundStartIndex, refundEndIndex);

                  // ── Reschedule Filtering & Pagination ──
                  final filteredReschedules = _filterReschedules(rawReschedules);
                  final totalReschedulePages = (filteredReschedules.length / _rowsPerPage).ceil();
                  final rescheduleStartIndex = _rescheduleCurrentPage * _rowsPerPage;
                  final rescheduleEndIndex = (rescheduleStartIndex + _rowsPerPage).clamp(0, filteredReschedules.length);
                  final pageReschedules = filteredReschedules.isEmpty
                      ? <Map<String, dynamic>>[]
                      : filteredReschedules.sublist(rescheduleStartIndex, rescheduleEndIndex);

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header Card ──
                              _buildHeader(allRefunds, currentOrdersTotal, relevantOrders.length),

                              // ── Top Main Tab Selector (Admin View only) ──
                              if (!widget.todayOnly) ...[
                                const SizedBox(height: 20),
                                _buildMainTabSelector(pendingRefundsCount, pendingReschedulesCount),
                              ],

                              if (_selectedMainTab == 0) ...[
                                if (!widget.todayOnly) ...[
                                  const SizedBox(height: 20),
                                  _buildAnalyticsGrid(allRefunds),
                                ],
                                const SizedBox(height: 24),

                                // ── Section Title ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              widget.todayOnly ? "Today's POS Refunds" : 'Refund Management',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            if (widget.todayOnly) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF14332E).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                                                ),
                                                child: Text(
                                                  'TODAY ONLY',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF14332E),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          widget.todayOnly
                                              ? "Displaying refund requests and records for today's orders"
                                              : 'Manage refund requests from customers and POS',
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
                                if (!widget.todayOnly) ...[
                                  const SizedBox(height: 12),
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
                                ],
                                const SizedBox(height: 16),
                              ] else ...[
                                // ── RESCHEDULE REQUESTS TAB HEADER & CONTROLS ──
                                const SizedBox(height: 20),
                                _buildRescheduleAnalyticsGrid(rawReschedules),
                                const SizedBox(height: 24),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reschedule Requests',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        Text(
                                          'Review, approve, or decline customer booking schedule changes',
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

                                // ── Reschedule Search Bar ──
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
                                    controller: _rescheduleSearchController,
                                    onChanged: (v) => setState(() {
                                      _rescheduleSearchQuery = v;
                                      _rescheduleCurrentPage = 0;
                                    }),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: 'Search by customer, email, reservation ID, or reason...',
                                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                      suffixIcon: _rescheduleSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                              onPressed: () => setState(() {
                                                _rescheduleSearchController.clear();
                                                _rescheduleSearchQuery = '';
                                              }),
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // ── Reschedule Filter Pills ──
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildRescheduleFilterPill('all', 'All Requests (${rawReschedules.length})', Icons.apps_rounded, const Color(0xFF14332E)),
                                      _buildRescheduleFilterPill('pending', 'Pending Approval (${rawReschedules.where((r) => r['status'] == 'pending').length})', Icons.hourglass_top_rounded, const Color(0xFFD97706)),
                                      _buildRescheduleFilterPill('approved', 'Approved (${rawReschedules.where((r) => r['status'] == 'approved').length})', Icons.check_circle_rounded, const Color(0xFF15803D)),
                                      _buildRescheduleFilterPill('rejected', 'Rejected (${rawReschedules.where((r) => r['status'] == 'rejected').length})', Icons.cancel_rounded, const Color(0xFFDC2626)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // ══════════════════════════════════════════
                      //  TAB 0: REFUNDS LIST
                      // ══════════════════════════════════════════
                      if (_selectedMainTab == 0) ...[
                        if (refundSnapshot.connectionState == ConnectionState.waiting && allRefunds.isEmpty)
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

                        if (totalRefundPages > 1)
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
                                      'Page ${_currentPage + 1} of $totalRefundPages',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _currentPage < totalRefundPages - 1 ? () => setState(() => _currentPage++) : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else ...[
                        // ══════════════════════════════════════════
                        //  TAB 1: RESCHEDULE REQUESTS LIST
                        // ══════════════════════════════════════════
                        if (rescheduleSnapshot.connectionState == ConnectionState.waiting && rawReschedules.isEmpty)
                          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF007AFF))))
                        else if (filteredReschedules.isEmpty)
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
                                        color: Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit_calendar_rounded, size: 48, color: Color(0xFF007AFF)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _rescheduleFilter == 'all' ? 'No reschedule requests yet' : 'No ${_rescheduleFilter} requests',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF64748B),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Customer reschedule requests will appear here for review',
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
                                if (index >= pageReschedules.length) return null;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                  child: _buildRescheduleCard(pageReschedules[index]),
                                );
                              },
                              childCount: pageReschedules.length,
                            ),
                          ),

                        if (totalReschedulePages > 1)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _rescheduleCurrentPage > 0 ? () => setState(() => _rescheduleCurrentPage--) : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Page ${_rescheduleCurrentPage + 1} of $totalReschedulePages',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _rescheduleCurrentPage < totalReschedulePages - 1 ? () => setState(() => _rescheduleCurrentPage++) : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Header Card (mirrors Petty Cash Executive Card) ───────
  Widget _buildHeader(List<Map<String, dynamic>> allRefunds, double currentOrdersTotal, int ordersCount) {
    double totalRefunded = 0;
    for (final r in allRefunds) {
      if (r['status'] == 'completed') {
        totalRefunded += (r['refund_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    final pending = allRefunds.where((r) => r['status'] == 'pending').length;
    final netSales = currentOrdersTotal;

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
                  Row(
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
                              widget.todayOnly ? 'TODAY POS NET SALES' : 'REFUND MANAGEMENT',
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
                    ],
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
                widget.todayOnly ? "TODAY'S NET SALES (KITA NGAYONG ARAW)" : 'TOTAL REFUNDED',
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
                    NumberFormat('#,##0.00').format(widget.todayOnly ? (netSales < 0 ? 0 : netSales) : totalRefunded),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                  ),
                ],
              ),
              if (!widget.todayOnly) ...[
                const SizedBox(height: 16),
                // Sub-stats row (Admin View)
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
            ],
          ),
        ],
      ),
    );
  }

  // ── Analytics grid (Admin View) ───────────────────────────
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

  // ── Filter Pill (Admin View) ──────────────────────────────
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

  // ══════════════════════════════════════════════════════════
  //  RESCHEDULE UI HELPERS & COMPONENTS
  // ══════════════════════════════════════════════════════════

  Widget _buildMainTabSelector(int pendingRefunds, int pendingReschedules) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedMainTab = 0),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMainTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMainTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: _selectedMainTab == 0 ? const Color(0xFF14332E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Refund Requests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: _selectedMainTab == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedMainTab == 0 ? const Color(0xFF14332E) : const Color(0xFF64748B),
                      ),
                    ),
                    if (pendingRefunds > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingRefunds',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedMainTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMainTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMainTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: _selectedMainTab == 1 ? const Color(0xFF007AFF) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reschedule Requests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: _selectedMainTab == 1 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedMainTab == 1 ? const Color(0xFF007AFF) : const Color(0xFF64748B),
                      ),
                    ),
                    if (pendingReschedules > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingReschedules',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  Widget _buildRescheduleAnalyticsGrid(List<Map<String, dynamic>> requests) {
    final total = requests.length;
    final pending = requests.where((r) => r['status'] == 'pending').length;
    final approved = requests.where((r) => r['status'] == 'approved').length;
    final rejected = requests.where((r) => r['status'] == 'rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildRescheduleStatCard('Total Requests', '$total', Icons.calendar_month_rounded, const Color(0xFF0F172A), cardWidth),
            _buildRescheduleStatCard('Pending Approval', '$pending', Icons.hourglass_top_rounded, const Color(0xFFD97706), cardWidth),
            _buildRescheduleStatCard('Approved', '$approved', Icons.check_circle_rounded, const Color(0xFF15803D), cardWidth),
            _buildRescheduleStatCard('Rejected', '$rejected', Icons.cancel_rounded, const Color(0xFFDC2626), cardWidth),
          ],
        );
      },
    );
  }

  Widget _buildRescheduleStatCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRescheduleFilterPill(String filterKey, String label, IconData icon, Color color) {
    final isSelected = _rescheduleFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() {
          _rescheduleFilter = filterKey;
          _rescheduleCurrentPage = 0;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0)),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRescheduleCard(Map<String, dynamic> request) {
    final customerName = request['customer_name']?.toString() ?? 'Customer';
    final customerEmail = request['customer_email']?.toString() ?? '';
    final customerPhone = request['customer_phone']?.toString() ?? '';
    final oldDate = request['old_date']?.toString() ?? '';
    final oldTime = request['old_time']?.toString() ?? '';
    final oldDuration = request['old_duration'];
    final oldGuests = request['old_guests'];
    final newDate = request['new_date']?.toString() ?? '';
    final newTime = request['new_time']?.toString() ?? '';
    final newDuration = request['new_duration'];
    final newGuests = request['new_guests'];
    final reason = request['reason']?.toString() ?? 'Customer requested reschedule';
    final status = (request['status'] ?? 'pending').toString().toLowerCase();
    final adminNotes = request['admin_notes'];
    final reviewedBy = request['reviewed_by'];

    String requestedAtStr = '';
    if (request['created_at'] != null) {
      try {
        final parsed = DateTime.parse(request['created_at'].toString()).toLocal();
        requestedAtStr = DateFormat('MMM dd, yyyy • h:mm a').format(parsed);
      } catch (_) {
        requestedAtStr = request['created_at'].toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'pending'
              ? const Color(0xFF007AFF).withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: status == 'pending' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Customer Info & Status Badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF007AFF), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (customerEmail.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.email_outlined, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  customerEmail,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          if (customerPhone.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  customerPhone,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (requestedAtStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Requested on: $requestedAtStr',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Schedule Comparison Banner ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Old Schedule
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORIGINAL SCHEDULE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$oldDate @ $oldTime',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (oldGuests != null || oldDuration != null)
                          Text(
                            '${oldDuration ?? 2}h • ${oldGuests ?? 1} guests',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),

                  // Arrow Indicator
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF007AFF), size: 16),
                  ),
                  const SizedBox(width: 12),

                  // Requested New Schedule
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REQUESTED NEW SCHEDULE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF007AFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF007AFF)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$newDate @ $newTime',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: const Color(0xFF007AFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (newGuests != null || newDuration != null)
                          Text(
                            '${newDuration ?? 2}h • ${newGuests ?? 1} guests',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Customer Reason ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: $reason',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Admin Notes if Reviewed ──
            if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: status == 'approved'
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin (${reviewedBy ?? "Admin"}): $adminNotes',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: status == 'approved' ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],

            // ── Action Buttons for Pending ──
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectRescheduleDialog(request),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showApproveRescheduleDialog(request),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Approve Schedule',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated Top Toast Notification Banner for Refund Management
class _RefundTopToastWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Duration duration;

  const _RefundTopToastWidget({
    required this.child,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_RefundTopToastWidget> createState() => _RefundTopToastWidgetState();
}

class _RefundTopToastWidgetState extends State<_RefundTopToastWidget>
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

  void _dismiss() async {
    if (!mounted) return;
    if (_animController.isAnimating) return;
    await _animController.reverse();
    widget.onDismiss();
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
            constraints: const BoxConstraints(maxWidth: 540),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta != null && details.primaryDelta! < -4) {
                      _dismiss();
                    }
                  },
                  onTap: _dismiss,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

