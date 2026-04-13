import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:yang_chow/services/paymongo_service.dart';

class GCashPaymentPage extends StatefulWidget {
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;

  const GCashPaymentPage({
    super.key,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
  });

  @override
  State<GCashPaymentPage> createState() => _GCashPaymentPageState();
}

class _GCashPaymentPageState extends State<GCashPaymentPage> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  String? _paymentUrl;
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();

  @override
  void initState() {
    super.initState();
    _initializeGCashPayment();
  }

  Future<void> _initializeGCashPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create GCash payment link
      final paymentLink = await PayMongoService.createGCashPaymentLink(
        amount: widget.depositAmount * 100, // Convert to cents
        description: 'GCash Deposit for Reservation',
        returnUrl: 'https://yourapp.com/payment/success',
        metadata: {
          'reservation_id': widget.reservationId,
          'payment_type': 'gcash_deposit',
        },
      );

      if (paymentLink['success'] == true) {
        setState(() {
          _paymentUrl = paymentLink['checkoutUrl'];
        });
      } else {
        throw Exception(paymentLink['error'] ?? 'Failed to create GCash payment');
      }
    } catch (e) {
      _showErrorDialog('Failed to initialize GCash payment: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchGCashPayment() async {
    if (_paymentUrl == null) return;

    try {
      final uri = Uri.parse(_paymentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        throw 'Could not launch GCash payment URL';
      }
    } catch (e) {
      _showErrorDialog('Failed to open GCash payment. Please try again.');
    }
  }

  void _handlePaymentSuccess() async {
    if (_paymentCompleted) return;
    
    setState(() {
      _paymentCompleted = true;
    });

    try {
      // Update reservation payment status (this will also update reservation status to confirmed)
      final success = await _reservationService.updatePaymentStatus(
        reservationId: widget.reservationId,
        paymentStatus: 'deposit_paid',
        paymentAmount: widget.depositAmount,
        paymentReference: 'GCASH_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!success) {
        throw Exception('Failed to update payment status');
      }

      // Send confirmation email
      await _sendPaymentConfirmationEmail();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      if (mounted) {
        _showErrorDialog('Payment was successful but failed to update reservation. Please contact support.');
      }
    }
  }

  Future<void> _sendPaymentConfirmationEmail() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _emailService.sendDepositPaymentConfirmation(
          customerEmail: currentUser.email!,
          customerName: currentUser.userMetadata?['name'] ?? 'Customer',
          eventType: 'Event',
          eventDate: 'TBD',
          depositAmount: widget.depositAmount,
        );
      }
    } catch (e) {
      debugPrint('Error sending payment confirmation email: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your GCash payment of PHP ${widget.depositAmount.toStringAsFixed(2)} has been successfully processed.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is being reviewed by admin.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Once approved, your reservation will be confirmed and you\'ll receive a confirmation email.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'Thank you for choosing GCash!',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to dashboard
              widget.onPaymentSuccess(); // Trigger refresh
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('GCash Payment Issue'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to try again
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GCash Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            _showCancelConfirmationDialog();
          },
        ),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'GCASH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.blue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Initializing GCash payment...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Powered by PayMongo',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _paymentCompleted
              ? Container(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'GCash Payment Successful!',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Processing your reservation...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Pay with GCash',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete your payment using GCash wallet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Payment Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PHP ${widget.depositAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to pay with GCash:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Click "Open GCash Payment" below',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Login to your GCash account',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Confirm the payment amount',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Complete the payment',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _launchGCashPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.account_balance_wallet),
                                  SizedBox(width: 8),
                                  Text('Open GCash Payment'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: _handlePaymentSuccess,
                        child: Text('I already completed the payment'),
                      ),
                    ],
                    ),
                  ),
                ),
      bottomNavigationBar: !_paymentCompleted
          ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your GCash payment is secure and encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel GCash Payment?'),
        content: Text('Are you sure you want to cancel this GCash payment? Your reservation will not be confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('No, Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close payment page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
