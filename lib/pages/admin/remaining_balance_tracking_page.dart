import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yang_chow/services/receipt_pdf_service.dart';
import 'package:google_fonts/google_fonts.dart';

final _moneyFmt = NumberFormat('#,##0.00', 'en_PH');
final _moneyFmt0 = NumberFormat('#,##0', 'en_PH');

class RemainingBalanceTrackingPage extends StatefulWidget {
  final bool isFullscreen;
  final bool isEmbedded;
  final int initialTab;
  const RemainingBalanceTrackingPage({
    super.key,
    this.isFullscreen = false,
    this.isEmbedded = false,
    this.initialTab = 0,
  });

  @override
  State<RemainingBalanceTrackingPage> createState() => _RemainingBalanceTrackingPageState();
}

class _RemainingBalanceTrackingPageState extends State<RemainingBalanceTrackingPage> {
  List<Map<String, dynamic>> _reservationsWithBalance = [];
  List<Map<String, dynamic>> _settledHistory = [];
  bool _isLoading = true;
  late int _selectedTab; // 0 = Outstanding, 1 = Settled History
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _loadData();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Load active reservations with deposit_paid status
      final reservationsResponse = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('payment_status', 'deposit_paid')
          .neq('is_archived', true)
          .order('created_at', ascending: false);

      // 2. Load settled / fully paid reservations for record history
      final settledResponse = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .inFilter('payment_status', ['fully_paid', 'paid'])
          .neq('is_archived', true)
          .order('updated_at', ascending: false)
          .limit(150);

      final allDepositRows = List<Map<String, dynamic>>.from(reservationsResponse);
      final List<Map<String, dynamic>> actualWithBalance = [];
      final List<Map<String, dynamic>> autoSettled = [];

      for (final res in allDepositRows) {
        final total = (res['total_price'] as num?)?.toDouble() ?? 0.0;
        final deposit = (res['deposit_amount'] as num?)?.toDouble() ?? (res['payment_amount'] as num?)?.toDouble() ?? 0.0;
        final paymentOption = res['payment_option']?.toString();
        final rawRem = (res['remaining_balance'] as num?)?.toDouble();
        final calculatedRem = rawRem ?? ((total > 0 && deposit > 0) ? (total - deposit) : null);

        // If it was explicitly a full payment OR deposit covers the whole total price (> 0)
        final isFullySettled = paymentOption == 'full' || 
                              (total > 0 && deposit >= total) || 
                              (calculatedRem != null && calculatedRem <= 0 && total > 0);

        if (isFullySettled) {
          // Update row in Supabase to fully_paid
          try {
            await Supabase.instance.client.from('reservations').update({
              'payment_status': 'fully_paid',
              'remaining_balance': 0,
              'payment_option': 'full',
              'payment_amount': total > 0 ? total : deposit,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', res['id']);
          } catch (_) {}
          autoSettled.add({...res, 'payment_status': 'fully_paid', 'remaining_balance': 0});
        } else {
          actualWithBalance.add(res);
        }
      }

      setState(() {
        _reservationsWithBalance = actualWithBalance;
        _settledHistory = [...autoSettled, ...List<Map<String, dynamic>>.from(settledResponse)];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading balance data: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading data: $e', Colors.red);
    }
  }

  Future<void> _markAsFullyPaid({
    required String id,
    required String table,
    required String customerEmail,
    required String customerName,
    required String eventType,
    String paymentMethod = 'Cash / Manual Settlement',
  }) async {
    try {
      final currentData = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('id', id)
          .single();

      final totalPrice = (currentData['total_price'] as num?)?.toDouble() ?? 0.0;
      final depositAmount = (currentData['deposit_amount'] as num?)?.toDouble() ?? 0.0;
      final settledBalance = (totalPrice - depositAmount).clamp(0.0, double.infinity);
      final currentAdmin = Supabase.instance.client.auth.currentUser?.email ?? 'admn.pagsanjan@gmail.com';

      final updates = <String, dynamic>{
        'payment_status': 'fully_paid',
        'remaining_balance': 0,
        'payment_amount': totalPrice,
        'status': 'confirmed',
        'transacted_by': currentAdmin,
        'payment_reference': currentData['payment_reference'] ?? paymentMethod,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await Supabase.instance.client
          .from('reservations')
          .update(updates)
          .eq('id', id);

      try {
        await NotificationService.sendNotification(
          recipientEmail: customerEmail,
          actorName: 'Admin',
          actionType: 'balance_cleared',
          reservationId: id,
          eventType: '$eventType — Remaining Balance Cleared (₱${_moneyFmt.format(settledBalance)})',
        );
      } catch (e) {
        debugPrint('Warning: remaining balance notification failed: $e');
      }

      final shortRef = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
      await AuditLogService.logActivity(
        action: 'SETTLEMENT',
        module: 'Payments',
        description: 'Admin cleared remaining balance of ₱${_moneyFmt.format(settledBalance)} for Reservation #$shortRef ($customerName - $eventType)',
        entityId: id,
        metadata: {
          'reservation_id': id,
          'customer_name': customerName,
          'customer_email': customerEmail,
          'event_type': eventType,
          'total_price': totalPrice,
          'deposit_amount': depositAmount,
          'settled_balance': settledBalance,
          'payment_method': paymentMethod,
          'transacted_by': currentAdmin,
        },
      );

      _showSnackBar('✓ Marked as fully paid and added to Settled History', Colors.green);
      
      // Show the receipt dialog immediately - do NOT rebuild page yet
      final updatedReservation = Map<String, dynamic>.from(currentData)..addAll(updates);
      if (mounted) {
        _showPaymentSuccessReceiptDialog(updatedReservation, settledBalance);
      }

      // Reload data in the background AFTER the dialog is shown (3s delay)
      // so the widget tree does not rebuild and dismiss the dialog
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadData();
      });
    } catch (e) {
      debugPrint('Error marking as fully paid: $e');
      _showSnackBar('Error updating payment: $e', Colors.red);
    }
  }

  void _showPaymentSuccessReceiptDialog(Map<String, dynamic> reservation, double cashSettled) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PaymentReceiptModal(
        reservation: reservation,
        cashSettled: cashSettled,
      ),
    );
  }

  // ── PayMongo Dynamic QR & Link Generation ───────────────────────────────

  Future<void> _generateOnsiteQrAndLink(Map<String, dynamic> item) async {
    final remainingBalance = _calculateRemainingBalance(item);
    final customerName = item['customer_name'] ?? 'Customer';
    final customerEmail = item['customer_email'] ?? '';
    final eventType = item['event_type'] ?? 'Reservation';
    final id = item['id'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF14332E)),
            SizedBox(width: 16),
            Expanded(child: Text('Generating Onsite GCash QR & Checkout link...')),
          ],
        ),
      ),
    );

    try {
      final response = await PayMongoService.createPaymentLink(
        amount: remainingBalance,
        description: 'Remaining Balance — $eventType ($customerName)',
        metadata: {
          'source': 'remaining_balance_onsite',
          'reservation_id': id,
          'customer_name': customerName,
          'customer_email': customerEmail,
          'event_type': eventType,
        },
      );

      if (mounted) Navigator.of(context).pop(); // close loading

      if (response['success'] == true && response['checkoutUrl'] != null) {
        final checkoutUrl = response['checkoutUrl'] as String;
        final linkId = response['linkId'] as String?;

        try {
          await Supabase.instance.client.from('reservations').update({
            'balance_link_id': linkId,
            'balance_link_url': checkoutUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', id);
        } catch (e) {
          debugPrint('Note: balance_link update skipped: $e');
        }

        try {
          await NotificationService.sendNotification(
            recipientEmail: customerEmail,
            actorName: 'Admin',
            actionType: 'balance_payment_link',
            reservationId: id,
            eventType: '$eventType — Pay Remaining Balance ₱${_moneyFmt.format(remainingBalance)} via: $checkoutUrl',
          );
        } catch (e) {
          debugPrint('Warning: notification failed: $e');
        }

        // Auto-open the official PayMongo QR Ph checkout page immediately in browser
        try {
          await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Warning: auto launchUrl error: $e');
        }

        if (mounted) {
          _showOnsiteQrModal(
            checkoutUrl: checkoutUrl,
            linkId: linkId,
            item: item,
            remainingBalance: remainingBalance,
          );
        }
      } else {
        throw Exception('Failed to generate PayMongo payment link');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnackBar('Error creating QR / Payment Link: $e', Colors.red);
    }
  }

  void _showOnsiteQrModal({
    required String checkoutUrl,
    String? linkId,
    required Map<String, dynamic> item,
    required double remainingBalance,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OnsiteQrPaymentDialog(
        checkoutUrl: checkoutUrl,
        linkId: linkId,
        item: item,
        remainingBalance: remainingBalance,
        onMarkCashPaid: (itemToPay) => _showMarkPaidDialog(itemToPay, true),
        onPaymentSuccess: (id, amount) async {
          await _markAsFullyPaid(
            id: id,
            table: 'reservations',
            customerEmail: item['customer_email'] ?? '',
            customerName: item['customer_name'] ?? 'Customer',
            eventType: item['event_type'] ?? 'Reservation',
            paymentMethod: 'PayMongo GCash (Onsite QR)',
          );
          if (mounted) {
            _showPaymentSuccessDialog(
              customerName: item['customer_name'] ?? 'Customer',
              shortRef: id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase(),
              amountPaid: amount,
            );
          }
        },
      ),
    );
  }

  void _showPaymentSuccessDialog({
    required String customerName,
    required String shortRef,
    required double amountPaid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF15803D).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 38, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Received Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              '₱${_moneyFmt.format(amountPaid)} settled for $customerName (#$shortRef)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Text(
                '✓ Moved to Settled Records History',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14332E),
                foregroundColor: const Color(0xFFD9A441),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettledDetailsDialog(Map<String, dynamic> item) {
    final customerName = item['customer_name'] ?? 'Guest Customer';
    final customerEmail = item['customer_email'] ?? 'No email';
    final eventType = item['event_type'] ?? 'Reservation';
    final orderId = item['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final settledAmount = (totalPrice - depositAmount).clamp(0.0, double.infinity);
    final paymentReference = item['payment_reference'] ?? 'Online / GCash';
    final updatedAt = item['updated_at']?.toString() ?? item['created_at']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF15803D).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settled Account Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('#$shortId · Fully Settled', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Account Fully Settled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                          Text('Settled On: ${_formatDateTime(updatedAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF166534))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _dialogInfoRow('Customer', customerName),
              _dialogInfoRow('Email', customerEmail),
              _dialogInfoRow('Event Type', eventType),
              _dialogInfoRow('Channel / Ref', paymentReference),
              const Divider(height: 20),
              _dialogPriceRow('Total Bill Amount:', '₱${_moneyFmt.format(totalPrice)}', isBold: false),
              const SizedBox(height: 4),
              _dialogPriceRow('Initial Deposit Paid:', '₱${_moneyFmt.format(depositAmount)}', color: const Color(0xFF0284C7)),
              const SizedBox(height: 4),
              _dialogPriceRow('Balance Cleared:', '₱${_moneyFmt.format(settledAmount)}', color: const Color(0xFF15803D), isBold: true),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Remaining Balance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    Text('₱0.00', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
            label: const Text('View / Print PDF Receipt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFD9A441),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => ReceiptPdfService.printOrShareVoucher(
              item,
              isPaymentReceipt: true,
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_rounded, size: 15),
            label: const Text('Show QR Pass', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16302A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showPaymentSuccessReceiptDialog(item, settledAmount);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogPriceRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFF475569), fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF0F172A), fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.green ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Map<String, dynamic>> get _currentDataset =>
      _selectedTab == 0 ? _reservationsWithBalance : _settledHistory;

  List<Map<String, dynamic>> get _filteredData {
    final dataset = _currentDataset;
    if (_searchQuery.isEmpty) {
      return dataset;
    }
    
    final query = _searchQuery.toLowerCase();
    return dataset.where((item) {
      final customerName = (item['customer_name'] as String?)?.toLowerCase() ?? '';
      final orderId = item['id'].toString().toLowerCase();
      final customerEmail = (item['customer_email'] as String?)?.toLowerCase() ?? '';
      final eventType = (item['event_type'] as String?)?.toLowerCase() ?? '';
      
      return customerName.contains(query) ||
             orderId.contains(query) ||
             customerEmail.contains(query) ||
             eventType.contains(query);
    }).toList();
  }

  double _calculateRemainingBalance(Map<String, dynamic> item) {
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingBalance = (item['remaining_balance'] as num?)?.toDouble();
    
    if (remainingBalance != null && remainingBalance > 0) return remainingBalance;
    return (totalPrice - depositAmount).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    final content = Padding(
      padding: isDesktop 
          ? EdgeInsets.zero 
          : ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop) ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );

    if (widget.isFullscreen && !widget.isEmbedded) {
      return Scaffold(
        backgroundColor: AppTheme.adminMainBackground,
        body: SafeArea(child: content),
      );
    }
    return content;
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: EdgeInsets.only(
        left: widget.isEmbedded ? 0 : 20,
        right: widget.isEmbedded ? 0 : 20,
        top: 0,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEmbedded) ...[
            _buildHeaderBanner(),
            const SizedBox(height: 12),
          ],
          _buildSummaryCards(),
          const SizedBox(height: 12),
          _buildTabSelector(),
          const SizedBox(height: 10),
          _buildSearchBar(),
          const SizedBox(height: 10),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (!widget.isEmbedded) ...[
          _buildHeaderBanner(),
          const SizedBox(height: 12),
        ],
        _buildSummaryCards(),
        const SizedBox(height: 12),
        _buildTabSelector(),
        const SizedBox(height: 10),
        _buildSearchBar(),
        const SizedBox(height: 10),
        Expanded(
          child: _buildCardList(),
        ),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
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
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD9A441), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remaining Balance Tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Monitor outstanding balances, collect via Onsite GCash QR, and inspect settlement history',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    
    double totalOutstanding = 0;
    for (var item in _reservationsWithBalance) {
      totalOutstanding += _calculateRemainingBalance(item);
    }

    double totalSettledRevenue = 0;
    for (var item in _settledHistory) {
      totalSettledRevenue += (item['total_price'] as num?)?.toDouble() ?? 0.0;
    }
    
    final pendingAccounts = _reservationsWithBalance.length;
    final settledAccounts = _settledHistory.length;

    final card1 = _buildMetricCard(
      title: 'Outstanding Balance',
      value: '₱${_moneyFmt.format(totalOutstanding)}',
      subtitle: '$pendingAccounts Pending Accounts',
      icon: Icons.pending_actions_rounded,
      color: const Color(0xFFDC2626),
      bg: const Color(0xFFFEE2E2),
    );
    final card2 = _buildMetricCard(
      title: 'Total Settled Revenue',
      value: '₱${_moneyFmt.format(totalSettledRevenue)}',
      subtitle: 'From settled transactions',
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF15803D),
      bg: const Color(0xFFDCFCE7),
    );
    final card3 = _buildMetricCard(
      title: 'Settlement History',
      value: '$settledAccounts Cleared',
      subtitle: 'Fully paid accounts',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFF0284C7),
      bg: const Color(0xFFE0F2FE),
    );

    if (!isDesktop) {
      return SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            SizedBox(width: 215, child: card1),
            const SizedBox(width: 10),
            SizedBox(width: 215, child: card2),
            const SizedBox(width: 10),
            SizedBox(width: 190, child: card3),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 14),
        Expanded(child: card2),
        const SizedBox(width: 14),
        Expanded(child: card3),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.mediumGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
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

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              index: 0,
              label: 'Outstanding Balances',
              count: _reservationsWithBalance.length,
              icon: Icons.hourglass_top_rounded,
              activeColor: const Color(0xFFDC2626),
              activeBgColor: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              index: 1,
              label: 'Settled Records History',
              count: _settledHistory.length,
              icon: Icons.verified_rounded,
              activeColor: const Color(0xFF15803D),
              activeBgColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required Color activeColor,
    required Color activeBgColor,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () {
        if (_selectedTab != index) {
          setState(() {
            _selectedTab = index;
            _currentPage = 0;
          });
        }
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
          });
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: _selectedTab == 0 
              ? 'Search outstanding balances by customer, ID, email...'
              : 'Search settled history by customer, ID, email...',
          hintStyle: const TextStyle(
            color: AppTheme.mediumGrey,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.mediumGrey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.mediumGrey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.adminChatButton),
        ),
      );
    }

    final filtered = _filteredData;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length) 
        ? startIndex + _rowsPerPage 
        : filtered.length;
    final paginatedData = filtered.sublist(startIndex, endIndex);
    
    return Container(
      constraints: const BoxConstraints(minHeight: double.infinity),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tableWidth = constraints.maxWidth < 1100 ? 1100.0 : constraints.maxWidth;
                final double availableWidth = (tableWidth - 32 - 84).clamp(0.0, double.infinity);
                
                final double customerWidth = availableWidth * 0.20;
                final double orderIdWidth = availableWidth * 0.11;
                final double eventDateWidth = availableWidth * 0.12;
                final double totalWidth = availableWidth * 0.12;
                final double paidWidth = availableWidth * 0.13;
                final double remainingWidth = availableWidth * 0.14;
                final double actionsWidth = availableWidth * 0.18;

                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: tableWidth,
                        child: DataTable(
                          columnSpacing: 12,
                          horizontalMargin: 16,
                          headingRowHeight: 46,
                          dataRowMinHeight: 68,
                          dataRowMaxHeight: 78,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                      columns: _selectedTab == 0
                          ? [
                              DataColumn(label: _buildColumnHeader('CUSTOMER', Icons.person_rounded)),
                              DataColumn(label: _buildColumnHeader('ORDER REF', Icons.tag_rounded)),
                              DataColumn(label: _buildColumnHeader('EVENT DATE', Icons.event_rounded)),
                              DataColumn(label: _buildColumnHeader('TOTAL BILL', Icons.receipt_long_rounded)),
                              DataColumn(label: _buildColumnHeader('PAYMENT PROGRESS', Icons.donut_large_rounded)),
                              DataColumn(label: _buildColumnHeader('OUTSTANDING', Icons.account_balance_wallet_rounded)),
                              DataColumn(label: _buildColumnHeader('ACTIONS', Icons.bolt_rounded)),
                            ]
                          : [
                              DataColumn(label: _buildColumnHeader('CUSTOMER', Icons.person_rounded)),
                              DataColumn(label: _buildColumnHeader('ORDER REF', Icons.tag_rounded)),
                              DataColumn(label: _buildColumnHeader('EVENT DATE', Icons.event_rounded)),
                              DataColumn(label: _buildColumnHeader('TOTAL SETTLED', Icons.receipt_long_rounded)),
                              DataColumn(label: _buildColumnHeader('INITIAL DEPOSIT', Icons.savings_rounded)),
                              DataColumn(label: _buildColumnHeader('SETTLEMENT STATUS', Icons.check_circle_rounded)),
                              DataColumn(label: _buildColumnHeader('DETAILS', Icons.visibility_rounded)),
                            ],
                      rows: paginatedData.map((item) {
                        int rowIndex = paginatedData.indexOf(item);
                        final remainingBalance = _calculateRemainingBalance(item);
                        final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                        final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
                        final double paidRatio = totalPrice > 0 ? (depositAmount / totalPrice).clamp(0.0, 1.0) : 0.0;
                        final String customerName = item['customer_name'] ?? 'Guest Customer';
                        final String customerInitial = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'G';
                        
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) {
                              return const Color(0xFFF1F5F9);
                            }
                            if (rowIndex.isEven) {
                              return const Color(0xFFF8FAFC);
                            }
                            return Colors.white;
                          }),
                          cells: _selectedTab == 0
                              ? [
                                  // Tab 0: Outstanding Cells
                                  DataCell(
                                    SizedBox(
                                      width: customerWidth,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF14332E),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                customerInitial,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFD9A441),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  customerName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  item['customer_email'] ?? 'No email',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF64748B),
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
                                  DataCell(
                                    SizedBox(
                                      width: orderIdWidth,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '#${item['id'].toString().substring(0, 8).toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF475569),
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: eventDateWidth,
                                      child: Text(
                                        _formatDate(item['event_date']?.toString() ?? item['created_at']?.toString() ?? ''),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: totalWidth,
                                      child: Text(
                                        '₱${_moneyFmt.format(totalPrice)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: paidWidth * 1.3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '₱${_moneyFmt0.format(depositAmount)} Paid',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                              ),
                                              Text(
                                                '${(paidRatio * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: paidRatio,
                                              backgroundColor: const Color(0xFFE2E8F0),
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                paidRatio >= 0.5 ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                              ),
                                              minHeight: 5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: remainingWidth,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 13,
                                              color: Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '₱${_moneyFmt.format(remainingBalance)}',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFDC2626),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: actionsWidth,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Open GCash QR button
                                          Tooltip(
                                            message: 'Open official PayMongo QR Ph page & listen for payment in real-time',
                                            child: ElevatedButton.icon(
                                              onPressed: () => _generateOnsiteQrAndLink(item),
                                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 13),
                                              label: const Text('Pay with GCash QR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0EA5E9),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shadowColor: Colors.transparent,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Mark Paid (cash/manual) button
                                          Tooltip(
                                            message: 'Settle remaining balance & mark fully paid (Cash)',
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showMarkPaidDialog(item, true),
                                              icon: const Icon(Icons.check_circle_rounded, size: 12),
                                              label: const Text('Mark Paid (Cash)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF14332E),
                                                foregroundColor: const Color(0xFFD9A441),
                                                elevation: 0,
                                                shadowColor: Colors.transparent,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(7),
                                                  side: const BorderSide(color: Color(0xFFD9A441), width: 0.8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                              : [
                                  // Tab 1: Settled History Cells
                                  DataCell(
                                    SizedBox(
                                      width: customerWidth,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF15803D),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                customerInitial,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  customerName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  item['customer_email'] ?? 'No email',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF64748B),
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
                                  DataCell(
                                    SizedBox(
                                      width: orderIdWidth,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '#${item['id'].toString().substring(0, 8).toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF475569),
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: eventDateWidth,
                                      child: Text(
                                        _formatDate(item['event_date']?.toString() ?? item['created_at']?.toString() ?? ''),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: totalWidth,
                                      child: Text(
                                        '₱${_moneyFmt.format(totalPrice)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: paidWidth,
                                      child: Text(
                                        '₱${_moneyFmt.format(depositAmount)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: remainingWidth,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF86EFAC)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF15803D)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Fully Settled',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: actionsWidth,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showSettledDetailsDialog(item),
                                        icon: const Icon(Icons.visibility_rounded, size: 13),
                                        label: const Text('View Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF14332E),
                                          foregroundColor: const Color(0xFFD9A441),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: const BorderSide(color: Color(0xFFD9A441), width: 0.8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
            ),
          ),
          if (filtered.length > _rowsPerPage)
            _buildPaginationControls(filtered.length),
        ],
      ),
    );
  }

  Widget _buildCardList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.adminChatButton),
        ),
      );
    }

    final filtered = _filteredData;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final remainingBalance = _calculateRemainingBalance(item);
        final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
        final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        final isSettled = _selectedTab == 1;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isSettled
                            ? const [Color(0xFF15803D), Color(0xFF86EFAC)]
                            : const [Color(0xFF14332E), Color(0xFFD9A441)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['customer_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                                      ),
                                      child: Text(
                                        '#${item['id'].toString().substring(0, 8).toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.mediumGrey.withValues(alpha: 0.9),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSettled
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFF14332E).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSettled
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFF14332E).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  isSettled ? '✓ Fully Settled' : (item['event_type'] ?? 'Reservation'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSettled ? const Color(0xFF15803D) : const Color(0xFF14332E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          _buildInfoRow('Event Date', _formatDate(item['event_date']?.toString() ?? item['created_at']?.toString() ?? ''), icon: Icons.event_rounded),
                          _buildInfoRow('Total Bill', '₱${_moneyFmt.format(totalPrice)}', icon: Icons.receipt_long_rounded),
                          _buildInfoRow('Deposit Paid', '₱${_moneyFmt.format(depositAmount)}', icon: Icons.savings_rounded, color: const Color(0xFF15803D)),
                          const SizedBox(height: 4),
                          if (!isSettled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
                                      SizedBox(width: 6),
                                      Text('Remaining Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                  Text('₱${_moneyFmt.format(remainingBalance)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _generateOnsiteQrAndLink(item),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                                label: const Text('Pay with GCash QR (Onsite)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EA5E9),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showMarkPaidDialog(item, true),
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: const Text('Mark as Fully Paid (Cash)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14332E),
                                  foregroundColor: const Color(0xFFD9A441),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFD9A441), width: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showSettledDetailsDialog(item),
                                icon: const Icon(Icons.visibility_rounded, size: 15),
                                label: const Text('View Settlement Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14332E),
                                  foregroundColor: const Color(0xFFD9A441),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFD9A441), width: 0.8),
                                  ),
                                ),
                              ),
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
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: AppTheme.mediumGrey),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems) 
        ? startIndex + _rowsPerPage 
        : totalItems;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    final currentPageDisplay = _currentPage + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.02),
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.12))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${startIndex + 1}–$endIndex of $totalItems',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· Page $currentPageDisplay of $totalPages',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 16),
          _buildPaginationButton(
            icon: Icons.chevron_left,
            onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 4),
          _buildPaginationButton(
            icon: Icons.chevron_right,
            onTap: endIndex < totalItems ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({required IconData icon, VoidCallback? onTap}) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.white : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? Colors.grey.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.adminChatButton : AppTheme.mediumGrey.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isOutstandingTab = _selectedTab == 0;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isOutstandingTab ? Colors.green : const Color(0xFF0284C7)).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOutstandingTab ? Icons.check_circle_outline_rounded : Icons.history_edu_rounded,
                size: 44,
                color: isOutstandingTab ? Colors.green : const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isOutstandingTab ? 'All Accounts Cleared!' : 'No Settled Records Found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isOutstandingTab
                  ? 'No outstanding balances at this time.\nAll accounts have been fully settled.'
                  : 'Settled records and payment history will appear here\nonce balance payments are completed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.darkGrey),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy · hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showMarkPaidDialog(Map<String, dynamic> item, bool isReservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Fully Paid (Cash)', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${item['customer_name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Event Type: ${item['event_type'] ?? 'N/A'}'),
              const SizedBox(height: 6),
              Text('Total: ₱${_moneyFmt.format((item['total_price'] as num?)?.toDouble() ?? 0.0)}'),
              const SizedBox(height: 6),
              Text('Deposit Paid: ₱${_moneyFmt.format((item['deposit_amount'] as num?)?.toDouble() ?? 0.0)}'),
              const SizedBox(height: 6),
              Text(
                'Remaining to Settle: ₱${_moneyFmt.format(_calculateRemainingBalance(item))}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 14),
              const Text('Are you sure you want to mark this account as fully paid in cash? It will move to Settled History.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsFullyPaid(
                id: item['id'],
                table: 'reservations',
                customerEmail: item['customer_email'] ?? '',
                customerName: item['customer_name'] ?? '',
                eventType: item['event_type'] ?? 'Reservation',
                paymentMethod: 'Cash Settlement (Admin)',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFD9A441),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );
  }
}

class _OnsiteQrPaymentDialog extends StatefulWidget {
  final String checkoutUrl;
  final String? linkId;
  final Map<String, dynamic> item;
  final double remainingBalance;
  final Function(Map<String, dynamic>) onMarkCashPaid;
  final Function(String, double) onPaymentSuccess;

  const _OnsiteQrPaymentDialog({
    required this.checkoutUrl,
    required this.linkId,
    required this.item,
    required this.remainingBalance,
    required this.onMarkCashPaid,
    required this.onPaymentSuccess,
  });

  @override
  State<_OnsiteQrPaymentDialog> createState() => _OnsiteQrPaymentDialogState();
}

class _OnsiteQrPaymentDialogState extends State<_OnsiteQrPaymentDialog> {
  Timer? _pollingTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    final linkId = widget.linkId;
    if (linkId == null) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _isChecking) return;
      _isChecking = true;
      try {
        final result = await PayMongoService.retrievePaymentLink(linkId);
        if (result['isPaid'] == true) {
          _pollingTimer?.cancel();
          if (mounted) {
            Navigator.of(context).pop();
            widget.onPaymentSuccess(widget.item['id'], widget.remainingBalance);
          }
        }
      } catch (e) {
        debugPrint('Onsite QR polling check error: $e');
      } finally {
        if (mounted) _isChecking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.item['customer_name'] ?? 'Guest Customer';
    final id = widget.item['id'] as String;
    final shortRef = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFD9A441), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Onsite QR Payment',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Scan to Settle Remaining Balance · #$shortRef',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AMOUNT TO COLLECT',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF991B1B), letterSpacing: 0.5),
                        ),
                        Text(
                          customerName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      '₱${_moneyFmt.format(widget.remainingBalance)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),

              // Official QR Ph Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF15803D),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Official QR Ph Page Opened',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The customer can now scan the QR Ph code on the browser screen directly using their GCash or Maya app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF15803D),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Real-time live status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF14332E),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Listening for payment in real-time...',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.checkoutUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Payment link copied to clipboard'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await launchUrl(Uri.parse(widget.checkoutUrl), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                      label: const Text('Open QR Ph Page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: const Color(0xFFD9A441),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFD9A441), width: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                _pollingTimer?.cancel();
                Navigator.pop(context);
                widget.onMarkCashPaid(widget.item);
              },
              icon: const Icon(Icons.payments_rounded, size: 15, color: Color(0xFF15803D)),
              label: const Text(
                'Customer paid in Cash',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () {
                _pollingTimer?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentReceiptModal extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final double cashSettled;

  const _PaymentReceiptModal({
    required this.reservation,
    required this.cashSettled,
  });

  @override
  State<_PaymentReceiptModal> createState() => _PaymentReceiptModalState();
}

class _PaymentReceiptModalState extends State<_PaymentReceiptModal> {
  String? _receiptPublicUrl;

  @override
  void initState() {
    super.initState();
    _generateAndUploadReceipt();
  }

  Future<void> _generateAndUploadReceipt() async {
    try {
      final orderId = widget.reservation['id']?.toString() ?? 'res_${DateTime.now().millisecondsSinceEpoch}';
      final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
      final filePath = 'receipts/Receipt_${shortId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 1. Generate the official PDF bytes with exact database data (PAYMENT RECEIPT mode)
      try {
        final pdfBytes = await ReceiptPdfService.generateReservationVoucherPdf(
          widget.reservation,
          isPaymentReceipt: true,
        );

        // 2. Try upload to Supabase Storage
        try {
          await Supabase.instance.client.storage.from('avatars').uploadBinary(
            filePath,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
          );
          final publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);
          if (mounted) {
            setState(() {
              _receiptPublicUrl = publicUrl;
            });
          }

          final reservationId = widget.reservation['id']?.toString();
          if (reservationId != null) {
            await Supabase.instance.client
                .from('reservations')
                .update({'receipt_url': publicUrl})
                .eq('id', reservationId);
          }
        } catch (uploadErr) {
          debugPrint('Note: Storage upload skipped or failed: $uploadErr');
        }
      } catch (e) {
        debugPrint('Error generating PDF: $e');
      }
    } catch (e) {
      debugPrint('Error in receipt generation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.reservation['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final customerName = widget.reservation['customer_name'] ?? 'Guest Customer';
    final customerEmail = widget.reservation['customer_email']?.toString() ?? '';
    final totalPrice = (widget.reservation['total_price'] as num?)?.toDouble() ?? 0.0;
    final depositAmount = (widget.reservation['deposit_amount'] as num?)?.toDouble() ?? 0.0;
    final transactedBy = (widget.reservation['transacted_by'] != null && widget.reservation['transacted_by'].toString().isNotEmpty)
        ? widget.reservation['transacted_by'].toString()
        : 'Admin Staff';

    final qrData = _receiptPublicUrl ?? 'YANGCHOW:RES:$orderId:$customerEmail:PAID';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Cash Payment Recorded & Settled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Official Digital E-Receipt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ref #$shortId · $customerName',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // Financial Summary Card
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
                        const Text('Total Contract Price:', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                        Text('₱${_moneyFmt.format(totalPrice)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Initial Deposit Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                        Text('₱${_moneyFmt.format(depositAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Final Cash Paid (Cleared):', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                        Text('₱${_moneyFmt.format(widget.cashSettled)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFCBD5E1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Balance:', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                        const Text('₱0.00 (FULLY PAID)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transacted By:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(transactedBy, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live QR Code for Customer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD9A441), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220.0,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        padding: const EdgeInsets.all(4),
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SCAN TO OPEN OFFICIAL E-RECEIPT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD9A441),
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Customer can point any phone camera to scan & open the official PDF receipt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              if (customerEmail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirmation email sent to $customerEmail',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('Download / Print PDF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16302A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => ReceiptPdfService.printOrShareVoucher(
                        widget.reservation,
                        isPaymentReceipt: true,
                      ),
                    ),
                  ),
                  if (_receiptPublicUrl != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Copy Link',
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF16302A)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _receiptPublicUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Receipt link copied to clipboard')),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

