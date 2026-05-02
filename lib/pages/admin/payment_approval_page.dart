import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/ocr_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Payment Approvals',
          style: TextStyle(
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.darkGrey),
        actions: [
          IconButton(
            onPressed: _loadPendingPayments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            color: AppTheme.primaryColor,
          ),
        ],
      ),
      body: _isLoading
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
                                color: AppTheme.primaryColor.withOpacity(0.2),
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
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    itemCount: _pendingPayments.length,
                    itemBuilder: (context, index) {
                      final payment = _pendingPayments[index];
                      // Staggered entrance animation effect
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(payment['id']),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 600)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
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
                    color: AppTheme.successGreen.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.successGreen.withOpacity(0.2), width: 2),
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
    final isMobile = ResponsiveUtils.isMobile(context);

    final String table = payment['_table'] ?? 'reservations';
    final bool isAdvanceOrder = table == 'advance_orders';

    // Common info containers
    Widget orderDetails = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdvanceOrder ? 'Advance Order Details' : 'Reservation Details',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mediumGrey),
          ),
          const SizedBox(height: 12),
          if (!isAdvanceOrder)
            _buildDetailRow('Event Type', payment['event_type'] ?? 'N/A', Icons.event),
          if (isAdvanceOrder)
            _buildDetailRow('Order Type', payment['order_type'] ?? 'N/A', Icons.fastfood_rounded, isHighlight: true),
          _buildDetailRow('Date', (isAdvanceOrder ? payment['order_date'] : payment['event_date']) ?? 'N/A', Icons.calendar_today),
          _buildDetailRow('Time', isAdvanceOrder ? (payment['order_time'] ?? 'N/A') : '${payment['start_time']} (${payment['duration_hours']}h)', Icons.access_time),
          if (!isAdvanceOrder || (payment['number_of_guests'] != null && payment['number_of_guests'] > 0))
            _buildDetailRow('Guests', '${payment['number_of_guests']} people', Icons.people),
        ],
      ),
    );

    Widget paymentDetails = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Customer', payment['customer_name'] ?? 'N/A', Icons.person),
          _buildDetailRow('Email', payment['customer_email'] ?? 'N/A', Icons.email),
          _buildDetailRow('Total Price', 'PHP ${(payment['total_price'] ?? 0).toStringAsFixed(2)}', Icons.monetization_on),
          _buildDetailRow('Deposit Paid', 'PHP ${(payment['deposit_amount'] ?? 0).toStringAsFixed(2)}', Icons.account_balance_wallet, isHighlight: true),
          if (payment['receipt_url'] != null && payment['receipt_url'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _viewReceiptImage(payment['receipt_url'].toString()),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('View Receipt', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _analyzingState[payment['id']] == true 
                      ? null 
                      : () => _analyzeReceipt(payment['id'], payment['receipt_url'].toString()),
                  icon: _analyzingState[payment['id']] == true 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.document_scanner, size: 18),
                  label: Text(_analyzingState[payment['id']] == true ? 'Analyzing...' : 'Auto-Verify', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.withOpacity(0.1),
                    foregroundColor: Colors.purple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
            
            // OCR Analysis Panel
            if (_ocrResults.containsKey(payment['id'])) ...[
              const SizedBox(height: 12),
              _buildOCRPanel(payment, _ocrResults[payment['id']]!),
            ],
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _HoverAnimatedCard(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Icon(Icons.access_time_filled, color: Colors.orange, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Received',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkGrey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ref: ${payment['payment_reference'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.orange),
                          SizedBox(width: 6),
                          Text(
                            'Awaiting Review',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Responsive content layout
                if (isMobile) ...[
                  orderDetails,
                  const SizedBox(height: 16),
                  paymentDetails,
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: orderDetails),
                      const SizedBox(width: 16),
                      Expanded(child: paymentDetails),
                    ],
                  ),
                ],
                
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isMobile) Expanded(
                      child: _buildActionButton(
                        onPressed: () => _showRejectDialog(payment),
                        icon: Icons.cancel_outlined,
                        label: 'Reject',
                        isPrimary: false,
                      ),
                    ) else _buildActionButton(
                      onPressed: () => _showRejectDialog(payment),
                      icon: Icons.cancel_outlined,
                      label: 'Reject',
                      isPrimary: false,
                    ),
                    const SizedBox(width: 16),
                    if (isMobile) Expanded(
                      child: _buildApproveButton(payment, table),
                    ) else _buildApproveButton(payment, table),
                  ],
                ),
                
                // Guidance note for disabled button
                if (!_canApprovePayment(payment['id']))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'Run Auto-Verify first to enable approval.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
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

  bool _canApprovePayment(String paymentId) {
    if (!_ocrResults.containsKey(paymentId)) return false;
    
    final ocr = _ocrResults[paymentId]!;
    if (ocr['success'] == false) return false;

    // Must have detected both amount and reference
    return ocr['detectedAmount'] != null && 
           (ocr['detectedRefs'] as List).isNotEmpty;
  }

  Widget _buildApproveButton(Map<String, dynamic> payment, String table) {
    final bool enabled = _canApprovePayment(payment['id']);
    
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amountMatches ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amountMatches ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_search, color: amountMatches ? Colors.green : Colors.orange, size: 16),
              const SizedBox(width: 8),
              const Text('OCR Verification Assistant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _buildOCRRow('Amount Detected', detectedAmount != null ? 'PHP ${detectedAmount.toStringAsFixed(2)}' : 'Not Found', amountMatches ? Icons.check_circle : (detectedAmount == null ? Icons.help_outline : Icons.warning_amber), amountMatches ? Colors.green : Colors.red),
          _buildOCRRow('Reference ID', detectedRefs.isNotEmpty ? detectedRefs.first.toString() : 'Not Found', refMatches ? Icons.check_circle : Icons.help_outline, refMatches ? Colors.green : Colors.orange),
          if (!amountMatches && detectedAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚠️ Warning: Amount mismatch (Expected PHP ${expectedAmount.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
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
              shadowColor: isDisabled ? Colors.transparent : AppTheme.successGreen.withOpacity(0.4),
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

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.primaryColor.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight ? AppTheme.primaryColor.withOpacity(0.15) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlight ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: isHighlight ? AppTheme.primaryColor : Colors.grey.shade500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                    color: isHighlight ? AppTheme.primaryColor : AppTheme.darkGrey,
                  ),
                ),
              ],
            ),
          ),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_isHovered ? 1.01 : 1.0)
          ..setTranslationRaw(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
