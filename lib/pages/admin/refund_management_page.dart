import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/services/refund_service.dart';
import 'package:yang_chow/services/reschedule_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

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
  final ScrollController _refundsTableScrollController = ScrollController();
  final ScrollController _reschedulesTableScrollController = ScrollController();

  int _selectedMainTab = 0; // 0: Refunds, 1: Reschedule Requests
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 0;

  String _rescheduleFilter = 'all';
  String _rescheduleSearchQuery = '';
  int _rescheduleCurrentPage = 0;
  final int _rowsPerPage = 10;
  bool _headerCollapsed = false;

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
    _refundsTableScrollController.dispose();
    _reschedulesTableScrollController.dispose();
    _dismissRefundTopToast();
    super.dispose();
  }

  // ── Design tokens ─────────────────────────────────────────
  static const _darkBg     = Color(0xFF0F172A);
  static const _emerald    = Color(0xFF14332E);
  static const _gold       = Color(0xFFD9A441);
  static const _slate      = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  // ── Status helpers ────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';
              final success = await _refundService.approveRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                adminNotes: notesController.text.isNotEmpty ? notesController.text : null,
              );
              if (success) {
                AuditLogService.logActivity(
                  action: 'APPROVE',
                  module: 'Refunds',
                  description: 'Approved refund request for ${refund['customer_name']} (Amount: ₱${refund['refund_amount']})',
                  entityId: refund['id']?.toString(),
                  metadata: {
                    'refund_id': refund['id'],
                    'customer_name': refund['customer_name'],
                    'refund_amount': refund['refund_amount'],
                    'notes': notesController.text.trim(),
                  },
                );
              }
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
              final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';
              final success = await _refundService.rejectRefund(
                refundId: refund['id'],
                adminEmail: adminEmail,
                rejectionReason: reasonController.text.trim(),
              );
              if (success) {
                AuditLogService.logActivity(
                  action: 'REJECT',
                  module: 'Refunds',
                  description: 'Rejected refund request for ${refund['customer_name']}. Reason: ${reasonController.text.trim()}',
                  entityId: refund['id']?.toString(),
                  metadata: {
                    'refund_id': refund['id'],
                    'customer_name': refund['customer_name'],
                    'refund_amount': refund['refund_amount'],
                    'reason': reasonController.text.trim(),
                  },
                );
              }
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
      final adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';
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

                  final isMobile = ResponsiveUtils.isMobile(context);

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, isMobile ? 14 : 24, isMobile ? 14 : 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Page Header (Matching Reservations Page) ──
                              _buildPageHeader(allRefunds, currentOrdersTotal, relevantOrders.length),

                              // ── Tab Selector ──
                              if (!widget.todayOnly) ...[
                                const SizedBox(height: 12),
                                _buildMainTabSelector(pendingRefundsCount, pendingReschedulesCount),
                              ],

                              // ── Stats Bar (Collapsible) ──
                              if (!_headerCollapsed) ...[
                                const SizedBox(height: 12),
                                _buildStatsBar(allRefunds, rawReschedules),
                              ],

                              // ── Compact Search Bar ──
                              const SizedBox(height: 12),
                              _buildSearchBar(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),

                      // ══════════════════════════════════════════
                      //  TAB 0: REFUNDS (TABLE / CARD LIST)
                      // ══════════════════════════════════════════
                      if (_selectedMainTab == 0) ...[
                        if (refundSnapshot.connectionState == ConnectionState.waiting && allRefunds.isEmpty)
                          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF14332E))))
                        else if (!isMobile)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildRefundsTable(filteredRefunds),
                            ),
                          )
                        else if (filteredRefunds.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: _buildEmptyRefundsState(),
                            ),
                          )
                        else ...[
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= pageRefunds.length) return null;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  child: _buildRefundCard(pageRefunds[index]),
                                );
                              },
                              childCount: pageRefunds.length,
                            ),
                          ),
                          if (totalRefundPages > 1)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _buildTablePaginationControls(
                                  currentPage: _currentPage,
                                  totalItems: filteredRefunds.length,
                                  itemLabel: 'refunds',
                                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                                ),
                              ),
                            ),
                        ],
                      ] else ...[
                        // ══════════════════════════════════════════
                        //  TAB 1: RESCHEDULE REQUESTS (TABLE / CARD LIST)
                        // ══════════════════════════════════════════
                        if (rescheduleSnapshot.connectionState == ConnectionState.waiting && rawReschedules.isEmpty)
                          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF007AFF))))
                        else if (!isMobile)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildReschedulesTable(filteredReschedules),
                            ),
                          )
                        else if (filteredReschedules.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: _buildEmptyReschedulesState(),
                            ),
                          )
                        else ...[
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= pageReschedules.length) return null;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  child: _buildRescheduleCard(pageReschedules[index]),
                                );
                              },
                              childCount: pageReschedules.length,
                            ),
                          ),
                          if (totalReschedulePages > 1)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _buildTablePaginationControls(
                                  currentPage: _rescheduleCurrentPage,
                                  totalItems: filteredReschedules.length,
                                  itemLabel: 'reschedule requests',
                                  onPageChanged: (newPage) => setState(() => _rescheduleCurrentPage = newPage),
                                ),
                              ),
                            ),
                        ],
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

  // ── Page Header (Matching Reservations Page Design) ─────────────
  Widget _buildPageHeader(List<Map<String, dynamic>> allRefunds, double currentOrdersTotal, int ordersCount) {
    double totalRefunded = 0;
    for (final r in allRefunds) {
      if (r['status'] == 'completed') {
        totalRefunded += (r['refund_amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ResponsiveUtils.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            color: _emerald.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.currency_exchange_rounded, color: _gold, size: 22),
                    ),
                    const Spacer(),
                    if (!widget.todayOnly) ...[
                      IconButton(
                        onPressed: _showChangePasscodeDialog,
                        icon: const Icon(Icons.lock_outline_rounded, color: _slate, size: 20),
                        tooltip: 'Change Passcode',
                      ),
                    ],
                    AnimatedRotation(
                      turns: _headerCollapsed ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: IconButton(
                        onPressed: () => setState(() => _headerCollapsed = !_headerCollapsed),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, color: _slate, size: 22),
                        tooltip: _headerCollapsed ? 'Show Stats' : 'Hide Stats',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      widget.todayOnly ? "Today's POS Refunds" : 'Refunds & Reschedules',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _darkBg,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (widget.todayOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TODAY ONLY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _emerald,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.todayOnly
                      ? "Displaying refund requests and records for today's orders"
                      : 'Manage, approve and track customer refunds and reschedule requests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slateLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: _slate),
                      const SizedBox(width: 6),
                      Text(
                        'Settled: ${_currencyFormat.format(totalRefunded)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _darkBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
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
                        color: _emerald.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: _gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.todayOnly ? "Today's POS Refunds" : 'Refunds & Reschedules',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _darkBg,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.todayOnly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _emerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'TODAY ONLY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _emerald,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.todayOnly
                            ? "Displaying refund requests and records for today's orders"
                            : 'Manage, approve and track customer refunds and reschedule requests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: _slate,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                // Total Settled Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slateLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: _slate),
                      const SizedBox(width: 6),
                      Text(
                        'Settled: ${_currencyFormat.format(totalRefunded)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _darkBg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.todayOnly) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showChangePasscodeDialog,
                    icon: const Icon(Icons.lock_outline_rounded, color: _slate, size: 20),
                    tooltip: 'Change Passcode',
                  ),
                ],
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _headerCollapsed ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: IconButton(
                    onPressed: () => setState(() => _headerCollapsed = !_headerCollapsed),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, color: _slate, size: 22),
                    tooltip: _headerCollapsed ? 'Show Stats' : 'Hide Stats',
                  ),
                ),
              ],
            ),
    );
  }

  // ── Tab Selector ──────────────────────────────────────────
  Widget _buildMainTabSelector(int pendingRefunds, int pendingReschedules) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slateLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              title: ResponsiveUtils.isMobile(context) ? 'Refunds' : 'Refund Requests',
              index: 0,
              icon: Icons.receipt_long_rounded,
              badgeCount: pendingRefunds,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              title: ResponsiveUtils.isMobile(context) ? 'Reschedules' : 'Reschedule Requests',
              index: 1,
              icon: Icons.edit_calendar_rounded,
              badgeCount: pendingReschedules,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required int index,
    required IconData icon,
    required int badgeCount,
  }) {
    final isSelected = _selectedMainTab == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedMainTab = index;
        _currentPage = 0;
        _rescheduleCurrentPage = 0;
      }),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _slate),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : _slate,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Stats Bar (Matching Reservations Page _statTile) ────────
  Widget _buildStatsBar(List<Map<String, dynamic>> allRefunds, List<Map<String, dynamic>> rawReschedules) {
    return Builder(
      builder: (context) {
        final isMobile = ResponsiveUtils.isMobile(context);

        Widget wrapStatTile(Widget tile) {
          return isMobile 
              ? Container(width: 140, margin: const EdgeInsets.only(right: 8), child: tile)
              : Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: tile));
        }

        if (_selectedMainTab == 0) {
          final pending   = allRefunds.where((r) => r['status'] == 'pending').length;
          final approved  = allRefunds.where((r) => r['status'] == 'approved').length;
          final completed = allRefunds.where((r) => r['status'] == 'completed').length;
          final rejected  = allRefunds.where((r) => r['status'] == 'rejected').length;

          final row = Row(
            children: [
              wrapStatTile(_statTile('Total Refunds', allRefunds.length, Icons.apps_rounded, const Color(0xFFF1F5F9), const Color(0xFF475569), 'all', isReschedule: false)),
              wrapStatTile(_statTile('Pending', pending, Icons.hourglass_top_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706), 'pending', isReschedule: false)),
              wrapStatTile(_statTile('Approved', approved, Icons.gpp_good_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'approved', isReschedule: false)),
              wrapStatTile(_statTile('Completed', completed, Icons.verified_rounded, const Color(0xFFE0F2FE), const Color(0xFF0284C7), 'completed', isReschedule: false)),
              wrapStatTile(_statTile('Rejected', rejected, Icons.cancel_rounded, const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'rejected', isReschedule: false)),
            ],
          );

          return isMobile 
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
              : row;
        } else {
          final pending   = rawReschedules.where((r) => r['status'] == 'pending').length;
          final approved  = rawReschedules.where((r) => r['status'] == 'approved').length;
          final rejected  = rawReschedules.where((r) => r['status'] == 'rejected').length;

          final row = Row(
            children: [
              wrapStatTile(_statTile('Total Requests', rawReschedules.length, Icons.apps_rounded, const Color(0xFFF1F5F9), const Color(0xFF475569), 'all', isReschedule: true)),
              wrapStatTile(_statTile('Pending Approval', pending, Icons.hourglass_top_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706), 'pending', isReschedule: true)),
              wrapStatTile(_statTile('Approved', approved, Icons.check_circle_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'approved', isReschedule: true)),
              wrapStatTile(_statTile('Rejected', rejected, Icons.cancel_rounded, const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'rejected', isReschedule: true)),
            ],
          );

          return isMobile 
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
              : row;
        }
      }
    );
  }

  Widget _statTile(
    String label,
    int value,
    IconData icon,
    Color bg,
    Color iconColor,
    String filterKey, {
    required bool isReschedule,
  }) {
    final isSelected = isReschedule
        ? _rescheduleFilter == filterKey
        : _selectedFilter == filterKey;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          if (isReschedule) {
            _rescheduleFilter = filterKey;
            _rescheduleCurrentPage = 0;
          } else {
            _selectedFilter = filterKey;
            _currentPage = 0;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? iconColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? iconColor : bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? Colors.white : iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? iconColor : _darkBg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: isSelected ? iconColor : _slate,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search Bar (Matching Reservations Page _buildSearchBar) ─
  Widget _buildSearchBar() {
    final isReschedule = _selectedMainTab == 1;
    final controller = isReschedule ? _rescheduleSearchController : _searchController;
    final query = isReschedule ? _rescheduleSearchQuery : _searchQuery;

    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: (v) => setState(() {
          if (isReschedule) {
            _rescheduleSearchQuery = v.trim();
            _rescheduleCurrentPage = 0;
          } else {
            _searchQuery = v.trim();
            _currentPage = 0;
          }
        }),
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: isReschedule
              ? 'Search by customer, email, reservation ID, or reason…'
              : 'Search by customer name, email, or transaction ID…',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    if (isReschedule) {
                      _rescheduleSearchQuery = '';
                      _rescheduleSearchController.clear();
                      _rescheduleCurrentPage = 0;
                    } else {
                      _searchQuery = '';
                      _searchController.clear();
                      _currentPage = 0;
                    }
                  }),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
      ),
    );
  }

  // ── Refund card (Clean Light Card with Soft Pastel Badges) ──
  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final status = (refund['status'] ?? 'pending').toString().toLowerCase();
    final sourceTable = (refund['source_table'] ?? '').toString();
    final refundMethod = (refund['refund_method'] ?? 'cash').toString();
    final amount = (refund['refund_amount'] as num?)?.toDouble() ?? 0;
    final originalAmount = (refund['original_amount'] as num?)?.toDouble() ?? 0;
    final requestedAt = refund['requested_at'] != null
        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(refund['requested_at']).toLocal())
        : 'N/A';
    final statusColor = _statusColor(status);

    Color statusBg;
    Color statusText;
    switch (status) {
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFF92400E);
        break;
      case 'approved':
      case 'completed':
        statusBg = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF166534);
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusText = const Color(0xFF991B1B);
        break;
      default:
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF475569);
    }

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: statusColor),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top badges row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Source badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_sourceIcon(sourceTable), size: 12, color: const Color(0xFF475569)),
                                const SizedBox(width: 5),
                                Text(
                                  _sourceLabel(sourceTable),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          // Refund method badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  refundMethod == 'paymongo' ? Icons.credit_card_rounded : Icons.payments_rounded,
                                  size: 12,
                                  color: const Color(0xFF475569),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  refundMethod == 'paymongo' ? 'PayMongo' : 'Cash',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(status), size: 12, color: statusText),
                                const SizedBox(width: 5),
                                Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: statusText),
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
                                    fontSize: 15,
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₱',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14332E),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    NumberFormat('#,##0.00').format(amount),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
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
                                  fontSize: 10,
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
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Admin: ${refund['admin_notes']}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
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
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (status == 'pending') ...[
                              OutlinedButton.icon(
                                onPressed: () => _showRejectDialog(refund),
                                icon: const Icon(Icons.close_rounded, size: 15),
                                label: Text('Reject', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(refund),
                                icon: const Icon(Icons.check_rounded, size: 15),
                                label: Text('Approve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14332E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                                ),
                              ),
                            ],
                            if (status == 'approved') ...[
                              if (refundMethod == 'paymongo')
                                ElevatedButton.icon(
                                  onPressed: () => _processPayMongoRefund(refund),
                                  icon: const Icon(Icons.credit_card_rounded, size: 15),
                                  label: Text('Process PayMongo Refund', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF14332E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _markCashReturned(refund),
                                  icon: const Icon(Icons.payments_rounded, size: 15),
                                  label: Text('Mark as Cash Returned', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF14332E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
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
  //  RESCHEDULE CARD (MOBILE FALLBACK)
  // ══════════════════════════════════════════════════════════

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

    Color statusBg;
    Color statusText;
    switch (status) {
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFF92400E);
        break;
      case 'approved':
      case 'completed':
        statusBg = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF166534);
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusText = const Color(0xFF991B1B);
        break;
      default:
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF475569);
    }

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Customer Info & Status Badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF14332E), size: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 12, color: statusText),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Schedule Comparison Banner ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 460;
                final oldScheduleWidget = Column(
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
                );

                final newScheduleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUESTED NEW SCHEDULE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14332E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF14332E)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$newDate @ $newTime',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: const Color(0xFF14332E),
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
                );

                if (isNarrow) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        oldScheduleWidget,
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF14332E)),
                              SizedBox(width: 6),
                              Text('Change requested to:', style: TextStyle(fontSize: 10.5, color: Color(0xFF14332E), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        newScheduleWidget,
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: oldScheduleWidget),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF475569), size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: newScheduleWidget),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Customer Reason ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    color: status == 'approved' ? const Color(0xFF166534) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],

            // ── Action Buttons for Pending ──
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectRescheduleDialog(request),
                    icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFDC2626)),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showApproveRescheduleDialog(request),
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: Text(
                      'Approve Schedule',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
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

  // ══════════════════════════════════════════════════════════
  //  DESKTOP TABLE IMPLEMENTATIONS (MATCHING RESERVATIONS PAGE)
  // ══════════════════════════════════════════════════════════

  Widget _tableHeader(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF475569),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _miniAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF14332E),
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
      const Color(0xFFD97706),
      const Color(0xFF0F766E),
    ];
    final c = colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Widget _buildTablePaginationControls({
    required int currentPage,
    required int totalItems,
    required String itemLabel,
    required ValueChanged<int> onPageChanged,
  }) {
    final startIndex = currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _slateLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems $itemLabel',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _slate,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: currentPage > 0 ? _emerald : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: currentPage > 0 ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page ${currentPage + 1} of $totalPages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _darkBg,
                  ),
                ),
              ),
              InkWell(
                onTap: endIndex < totalItems ? () => onPageChanged(currentPage + 1) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: endIndex < totalItems ? _emerald : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: endIndex < totalItems ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRefundsState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all' ? 'No refund records found' : 'No $_selectedFilter refunds',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Refund requests will appear in this table once initiated',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReschedulesState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_calendar_rounded, size: 40, color: Color(0xFF007AFF)),
            ),
            const SizedBox(height: 16),
            Text(
              _rescheduleFilter == 'all' ? 'No reschedule requests found' : 'No $_rescheduleFilter reschedule requests',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer reschedule requests will appear in this table for review',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── REFUNDS TABLE ──────────────────────────────────────────

  Widget _buildRefundsTable(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) return _buildEmptyRefundsState();

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length)
        ? startIndex + _rowsPerPage
        : filtered.length;
    final paginatedRefunds = filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth < 1100 ? 1100.0 : constraints.maxWidth;
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: Scrollbar(
                  controller: _refundsTableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _refundsTableScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: SizedBox(
                      width: minWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              border: Border(bottom: BorderSide(color: _slateLight, width: 1.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _tableHeader('TRANSACTION / SOURCE')),
                                Expanded(flex: 3, child: _tableHeader('CUSTOMER')),
                                Expanded(flex: 2, child: _tableHeader('AMOUNT & METHOD')),
                                Expanded(flex: 3, child: _tableHeader('REASON & DATE')),
                                SizedBox(width: 110, child: _tableHeader('STATUS')),
                                SizedBox(width: 170, child: _tableHeader('ACTIONS')),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: paginatedRefunds.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: _slateLight.withValues(alpha: 0.8),
                            ),
                            itemBuilder: (context, index) {
                              final r = paginatedRefunds[index];
                              return _buildRefundTableRow(r);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (filtered.length > _rowsPerPage)
            _buildTablePaginationControls(
              currentPage: _currentPage,
              totalItems: filtered.length,
              itemLabel: 'refunds',
              onPageChanged: (newPage) => setState(() => _currentPage = newPage),
            ),
        ],
      ),
    );
  }

  Widget _buildRefundTableRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final sourceTable = (r['source_table'] ?? '').toString();
    final refundMethod = (r['refund_method'] ?? 'cash').toString().toLowerCase();
    final amount = (r['refund_amount'] as num?)?.toDouble() ?? 0.0;
    final originalAmount = (r['original_amount'] as num?)?.toDouble() ?? 0.0;
    final customerName = r['customer_name']?.toString() ?? 'N/A';
    final customerContact = r['customer_email'] ?? r['customer_phone'] ?? 'No contact info';
    final txId = r['transaction_id'] ?? (r['id'] != null ? r['id'].toString().substring(0, 8) : 'N/A');
    final refundType = (r['refund_type'] ?? 'FULL').toString().toUpperCase();
    final reason = r['refund_reason']?.toString() ?? 'No reason provided';
    final requestedAtStr = r['requested_at'] != null
        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(r['requested_at']).toLocal())
        : (r['created_at'] != null
            ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(r['created_at']).toLocal())
            : 'N/A');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // 1. Transaction / Source
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_sourceIcon(sourceTable), size: 11, color: const Color(0xFF475569)),
                          const SizedBox(width: 4),
                          Text(
                            _sourceLabel(sourceTable),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: refundMethod == 'paymongo'
                            ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                            : const Color(0xFF15803D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        refundMethod == 'paymongo' ? 'PAYMONGO' : 'CASH',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: refundMethod == 'paymongo'
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tx: #$txId',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 2. Customer
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _miniAvatar(customerName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customerContact,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: _slate,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Amount & Method
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '₱${NumberFormat('#,##0.00').format(amount)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: _emerald,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'of ₱${NumberFormat('#,##0.00').format(originalAmount)} ($refundType)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: _slate,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 4. Reason & Date
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        requestedAtStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF475569),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 5. Status
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildCompactRefundStatusChip(status),
            ),
          ),

          // 6. Actions
          SizedBox(
            width: 170,
            child: _buildCompactRefundActionButtons(r),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRefundStatusChip(String status) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();
    switch (status) {
      case 'pending':
        color = const Color(0xFFD97706);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'approved':
        color = const Color(0xFF15803D);
        icon = Icons.gpp_good_rounded;
        break;
      case 'completed':
        color = const Color(0xFF0284C7);
        icon = Icons.verified_rounded;
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = _slate;
        icon = Icons.help_outline_rounded;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRefundActionButtons(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final refundMethod = (r['refund_method'] ?? 'cash').toString().toLowerCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactActionButton(
            icon: Icons.visibility_outlined,
            color: AppTheme.infoBlue,
            tooltip: 'View Details',
            onPressed: () => _showRefundDetailsDialog(r),
          ),
          if (status == 'pending') ...[
            _buildCompactActionButton(
              icon: Icons.check_circle_outline,
              color: AppTheme.successGreen,
              tooltip: 'Approve Refund',
              onPressed: () => _showApproveDialog(r),
            ),
            _buildCompactActionButton(
              icon: Icons.close_rounded,
              color: AppTheme.errorRed,
              tooltip: 'Reject Refund',
              onPressed: () => _showRejectDialog(r),
            ),
          ],
          if (status == 'approved') ...[
            if (refundMethod == 'paymongo')
              _buildCompactActionButton(
                icon: Icons.credit_card_rounded,
                color: const Color(0xFF14332E),
                tooltip: 'Process PayMongo Refund',
                onPressed: () => _processPayMongoRefund(r),
              )
            else
              _buildCompactActionButton(
                icon: Icons.payments_rounded,
                color: const Color(0xFF14332E),
                tooltip: 'Mark Cash Returned',
                onPressed: () => _markCashReturned(r),
              ),
          ],
        ],
      ),
    );
  }

  void _showRefundDetailsDialog(Map<String, dynamic> refund) {
    final status = (refund['status'] ?? 'pending').toString().toLowerCase();
    final sourceTable = (refund['source_table'] ?? '').toString();
    final refundMethod = (refund['refund_method'] ?? 'cash').toString();
    final amount = (refund['refund_amount'] as num?)?.toDouble() ?? 0;
    final originalAmount = (refund['original_amount'] as num?)?.toDouble() ?? 0;
    final requestedAt = refund['requested_at'] != null
        ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(refund['requested_at']).toLocal())
        : (refund['created_at'] != null
            ? DateFormat('MMM dd, yyyy · h:mm a').format(DateTime.parse(refund['created_at']).toLocal())
            : 'N/A');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _emerald, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refund Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _darkBg,
                    ),
                  ),
                  Text(
                    'Tx: #${refund['transaction_id'] ?? refund['id']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _slate,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _buildCompactRefundStatusChip(status),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                // Customer Information
                Row(
                  children: [
                    _miniAvatar(refund['customer_name'] ?? '?'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            refund['customer_name'] ?? 'N/A',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _darkBg,
                            ),
                          ),
                          Text(
                            refund['customer_email'] ?? refund['customer_phone'] ?? 'No contact',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Financial Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Refund Amount', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate, fontWeight: FontWeight.w600)),
                          Text(
                            _currencyFormat.format(amount),
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: _emerald),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Original Amount', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate)),
                          Text(_currencyFormat.format(originalAmount), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _darkBg)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Source & Method', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate)),
                          Text('${_sourceLabel(sourceTable)} · ${refundMethod.toUpperCase()}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Requested Date', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate)),
                          Text(requestedAt, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _darkBg)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (refund['refund_reason'] != null) ...[
                  const SizedBox(height: 12),
                  Text('Reason', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _darkBg)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      refund['refund_reason'],
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                if (refund['admin_notes'] != null && refund['admin_notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Admin Notes', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _darkBg)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      refund['admin_notes'],
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
          ),
          if (status == 'pending') ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(refund);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showApproveDialog(refund);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ],
          if (status == 'approved') ...[
            if (refundMethod.toLowerCase() == 'paymongo')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _processPayMongoRefund(refund);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Process PayMongo'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markCashReturned(refund);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark Cash Returned'),
              ),
          ],
        ],
      ),
    );
  }

  // ── RESCHEDULES TABLE ──────────────────────────────────────

  Widget _buildReschedulesTable(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) return _buildEmptyReschedulesState();

    final startIndex = _rescheduleCurrentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length)
        ? startIndex + _rowsPerPage
        : filtered.length;
    final paginatedReschedules = filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth < 1100 ? 1100.0 : constraints.maxWidth;
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: Scrollbar(
                  controller: _reschedulesTableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _reschedulesTableScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: SizedBox(
                      width: minWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              border: Border(bottom: BorderSide(color: _slateLight, width: 1.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _tableHeader('CUSTOMER & REF')),
                                Expanded(flex: 3, child: _tableHeader('ORIGINAL SCHEDULE')),
                                Expanded(flex: 3, child: _tableHeader('REQUESTED SCHEDULE')),
                                Expanded(flex: 2, child: _tableHeader('REASON & FILED')),
                                SizedBox(width: 110, child: _tableHeader('STATUS')),
                                SizedBox(width: 170, child: _tableHeader('ACTIONS')),
                              ],
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: paginatedReschedules.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: _slateLight.withValues(alpha: 0.8),
                            ),
                            itemBuilder: (context, index) {
                              final req = paginatedReschedules[index];
                              return _buildRescheduleTableRow(req);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (filtered.length > _rowsPerPage)
            _buildTablePaginationControls(
              currentPage: _rescheduleCurrentPage,
              totalItems: filtered.length,
              itemLabel: 'reschedule requests',
              onPageChanged: (newPage) => setState(() => _rescheduleCurrentPage = newPage),
            ),
        ],
      ),
    );
  }

  Widget _buildRescheduleTableRow(Map<String, dynamic> req) {
    final customerName = req['customer_name']?.toString() ?? 'Customer';
    final customerContact = req['customer_email'] ?? req['customer_phone'] ?? 'No contact';
    final oldDate = req['old_date']?.toString() ?? '';
    final oldTime = req['old_time']?.toString() ?? '';
    final oldDuration = req['old_duration'];
    final oldGuests = req['old_guests'];
    final newDate = req['new_date']?.toString() ?? '';
    final newTime = req['new_time']?.toString() ?? '';
    final newDuration = req['new_duration'];
    final newGuests = req['new_guests'];
    final reason = req['reason']?.toString() ?? 'Customer requested reschedule';
    final status = (req['status'] ?? 'pending').toString().toLowerCase();

    String requestedAtStr = 'N/A';
    if (req['created_at'] != null) {
      try {
        final parsed = DateTime.parse(req['created_at'].toString()).toLocal();
        requestedAtStr = DateFormat('MMM dd, yyyy · h:mm a').format(parsed);
      } catch (_) {
        requestedAtStr = req['created_at'].toString();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // 1. Customer & Ref
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _miniAvatar(customerName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customerContact,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: _slate,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Original Schedule
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$oldDate @ $oldTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${oldDuration ?? 2}h • ${oldGuests ?? 1} guests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 3. Requested Schedule
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available_rounded, size: 12, color: Color(0xFF14332E)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$newDate @ $newTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14332E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${newDuration ?? 2}h • ${newGuests ?? 1} guests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 4. Reason & Filed
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        requestedAtStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _darkBg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF475569),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 5. Status
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildCompactRescheduleStatusChip(status),
            ),
          ),

          // 6. Actions
          SizedBox(
            width: 170,
            child: _buildCompactRescheduleActionButtons(req),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRescheduleStatusChip(String status) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();
    switch (status) {
      case 'pending':
        color = const Color(0xFFD97706);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'approved':
      case 'completed':
        color = const Color(0xFF15803D);
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = _slate;
        icon = Icons.help_outline_rounded;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRescheduleActionButtons(Map<String, dynamic> req) {
    final status = (req['status'] ?? 'pending').toString().toLowerCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactActionButton(
            icon: Icons.visibility_outlined,
            color: AppTheme.infoBlue,
            tooltip: 'View Details',
            onPressed: () => _showRescheduleDetailsDialog(req),
          ),
          if (status == 'pending') ...[
            _buildCompactActionButton(
              icon: Icons.check_circle_outline,
              color: AppTheme.successGreen,
              tooltip: 'Approve Schedule',
              onPressed: () => _showApproveRescheduleDialog(req),
            ),
            _buildCompactActionButton(
              icon: Icons.close_rounded,
              color: AppTheme.errorRed,
              tooltip: 'Reject Schedule',
              onPressed: () => _showRejectRescheduleDialog(req),
            ),
          ],
        ],
      ),
    );
  }

  void _showRescheduleDetailsDialog(Map<String, dynamic> request) {
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF007AFF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reschedule Details',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _darkBg,
                ),
              ),
            ),
            _buildCompactRescheduleStatusChip(status),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                // Customer Information
                Row(
                  children: [
                    _miniAvatar(customerName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _darkBg,
                            ),
                          ),
                          Text(
                            customerEmail.isNotEmpty ? customerEmail : (customerPhone.isNotEmpty ? customerPhone : 'No contact info'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Schedule comparison
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CURRENT SCHEDULE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _slate)),
                                const SizedBox(height: 4),
                                Text('$oldDate @ $oldTime', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _darkBg)),
                                Text('${oldDuration ?? 2}h • ${oldGuests ?? 1} guests', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('REQUESTED SCHEDULE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                                const SizedBox(height: 4),
                                Text('$newDate @ $newTime', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: _emerald)),
                                Text('${newDuration ?? 2}h • ${newGuests ?? 1} guests', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Reason for Rescheduling', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _darkBg)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                  ),
                ),
                if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Admin Notes', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _darkBg)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: status == 'approved' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      adminNotes.toString(),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: status == 'approved' ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
          ),
          if (status == 'pending') ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectRescheduleDialog(request);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showApproveRescheduleDialog(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve Schedule'),
            ),
          ],
        ],
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

