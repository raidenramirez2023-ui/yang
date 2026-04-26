import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';

class GCashQRPaymentPage extends StatefulWidget {
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;
  final String table; // 'reservations' or 'advance_orders'

  const GCashQRPaymentPage({
    super.key,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
    this.table = 'reservations',
  });

  @override
  State<GCashQRPaymentPage> createState() => _GCashQRPaymentPageState();
}

class _GCashQRPaymentPageState extends State<GCashQRPaymentPage> {
  bool _paymentConfirmed = false;
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              // QR Code Section
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.65,
                color: Colors.white,
                child: Center(
                  child: Image.asset(
                    'assets/images/gcash_qr.png',
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 64),
                          SizedBox(height: 16),
                          Text('QR Code not found'),
                          Text('Please add gcash_qr.png to assets/images/'),
                        ],
                      );
                    },
                  ),
                ),
              ),
              
              // Test Payment Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Test Payment Method',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleTestPayment(),
                        icon: const Icon(Icons.payment),
                        label: Text('Test Pay (PHP ${widget.depositAmount.toStringAsFixed(2)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For testing purposes only',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTestPayment() async {
    if (_paymentConfirmed) return; // Prevent multiple calls
    
    setState(() {
      _paymentConfirmed = true;
    });

    try {
      // Update payment status
      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: widget.table == 'reservations' ? 'deposit_paid' : 'paid',
        table: widget.table,
        paymentAmount: widget.depositAmount,
        paymentReference: 'TEST_PAYMENT_${DateTime.now().millisecondsSinceEpoch}',
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
        setState(() {
          _paymentConfirmed = false; // Reset state on error
        });
        _showErrorDialog('Test payment failed. Please contact support.');
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
        title: const Row(
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
              'Your GCash payment of PHP ${widget.depositAmount.toStringAsFixed(2)} has been confirmed.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
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
            const SizedBox(height: 8),
            Text(
              'Once approved, your reservation will be confirmed and you\'ll receive a confirmation email.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Payment Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

}
