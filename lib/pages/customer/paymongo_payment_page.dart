import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';

class PayMongoPaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;

  const PayMongoPaymentPage({
    super.key,
    required this.paymentUrl,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
  });

  @override
  State<PayMongoPaymentPage> createState() => _PayMongoPaymentPageState();
}

class _PayMongoPaymentPageState extends State<PayMongoPaymentPage> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();

  @override
  void initState() {
    super.initState();
    _launchPayment();
  }

  Future<void> _launchPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        throw 'Could not launch payment URL';
      }
    } catch (e) {
      _showErrorDialog('Failed to open payment page. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handlePaymentSuccess() async {
    if (_paymentCompleted) return; // Prevent multiple calls
    
    setState(() {
      _paymentCompleted = true;
    });

    try {
      // Update reservation payment status (this will also update reservation status to confirmed)
      final success = await _reservationService.updatePaymentStatus(
        reservationId: widget.reservationId,
        paymentStatus: 'deposit_paid',
        paymentAmount: widget.depositAmount,
        paymentReference: 'PAYMONGO_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!success) {
        throw Exception('Failed to update payment status');
      }

      // Send confirmation email
      await _sendPaymentConfirmationEmail();

      if (mounted) {
        // Show success dialog
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      if (mounted) {
        _showErrorDialog('Payment was successful but failed to update reservation. Please contact support.');
      }
    }
  }

  void _handlePaymentFailed() {
    if (mounted) {
      _showErrorDialog('Payment was cancelled or failed. You can try again.');
    }
  }

  Future<void> _sendPaymentConfirmationEmail() async {
    try {
      // Get reservation details for email
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
              'Your payment of PHP ${widget.depositAmount.toStringAsFixed(2)} has been successfully processed.',
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
              'Thank you for your payment!',
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
            Text('Payment Issue'),
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
        title: Text('Secure Payment'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            _showCancelConfirmationDialog();
          },
        ),
        actions: [
          if (!_paymentCompleted)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'SECURE',
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
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Opening secure payment...',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
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
                          'Payment Successful!',
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
              : Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        color: AppTheme.primaryColor,
                        size: 80,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Payment Redirected',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'You have been redirected to PayMongo secure payment gateway.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete the payment in your browser and return here to confirm.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
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
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handlePaymentSuccess,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text('I Completed Payment'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _handlePaymentFailed,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text('I Cancelled'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: _launchPayment,
                        child: Text('Reopen Payment Page'),
                      ),
                    ],
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
                  Icon(Icons.security, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment information is secure and encrypted',
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
        title: Text('Cancel Payment?'),
        content: Text('Are you sure you want to cancel this payment? Your reservation will not be confirmed.'),
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
