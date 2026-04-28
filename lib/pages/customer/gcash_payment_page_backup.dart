import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:image_picker/image_picker.dart';

class GCashPaymentPage extends StatefulWidget {
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;
  final String table; // 'reservations' or 'advance_orders'

  const GCashPaymentPage({
    super.key,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
    this.table = 'reservations',
  });

  @override
  State<GCashPaymentPage> createState() => _GCashPaymentPageState();
}

class _GCashPaymentPageState extends State<GCashPaymentPage> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  bool _isConfirmed = false;
  String? _paymentUrl;
  XFile? _receiptImage;
  String? _receiptImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
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
      // QR code is now displayed directly on the page
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showErrorDialog('Failed to initialize payment: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // Check MIME type instead of file extension (more reliable)
        final mimeType = await image.mimeType;
        if (mimeType == null || 
            !mimeType.startsWith('image/') ||
            !['image/png', 'image/jpeg', 'image/jpg'].contains(mimeType.toLowerCase())) {
          _showErrorDialog('Please select a PNG, JPG, or JPEG image file.');
          return;
        }

        setState(() {
          _receiptImage = image;
        });

        // Upload to Supabase storage
        await _uploadReceiptToSupabase(image);
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _uploadReceiptToSupabase(XFile image) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final fileName = 'gcash_receipt_${DateTime.now().millisecondsSinceEpoch}.${image.path.split('.').last}';
      final filePath = 'receipts/$fileName';

      final fileBytes = await image.readAsBytes();

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, fileBytes);

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      setState(() {
        _receiptImageUrl = imageUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to upload receipt: $e');
    }
  }


  void _handlePaymentSuccess() async {
    if (_paymentCompleted) return;

    // Validate receipt upload for both advance orders and reservations
    if (_receiptImageUrl == null) {
      _showErrorDialog('Please upload your GCash receipt.');
      return;
    }

    setState(() {
      _paymentCompleted = true;
    });

    try {
      // Use widget.depositAmount directly for both advance orders and reservations
      final depositAmount = widget.depositAmount;

      debugPrint('Attempting to update payment status for ${widget.table} with ID: ${widget.reservationId}');
      debugPrint('Deposit amount: $depositAmount');
      debugPrint('Receipt URL: $_receiptImageUrl');

      // Update payment status with receipt_url for both advance_orders and reservations
      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: widget.table == 'reservations' ? 'deposit_paid' : 'pending_verification',
        table: widget.table,
        paymentAmount: depositAmount,
        paymentReference: 'GCASH_${DateTime.now().millisecondsSinceEpoch}',
        receiptUrl: _receiptImageUrl,
      );

      debugPrint('Payment status update result: $success');

      if (!success) {
        throw Exception('Failed to update payment status');
      }

      // Send confirmation email
      await _sendPaymentConfirmationEmail(depositAmount);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      if (mounted) {
        _showErrorDialog('Payment was successful but failed to update reservation. Error: $e');
      }
    }
  }

  Future<void> _sendPaymentConfirmationEmail(double depositAmount) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _emailService.sendDepositPaymentConfirmation(
          customerEmail: currentUser.email!,
          customerName: currentUser.userMetadata?['name'] ?? 'Customer',
          eventType: 'Event',
          eventDate: 'TBD',
          depositAmount: depositAmount,
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
            Text('Payment Pending Approval'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your GCash payment is pending admin approval. Once verified, your order will be sent to the kitchen.',
              style: TextStyle(fontSize: 16),
            ),
            if (widget.table == 'reservations') ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
            ] else ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded, color: AppTheme.successGreen, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🕐 Advance order submitted! Admin will review your payment shortly.',
                        style: TextStyle(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        backgroundColor: AppTheme.primaryColor,
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
              color: AppTheme.primaryColor.withOpacity(0.9),
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
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Initializing GCash payment...',
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
                  color: Colors.green.withOpacity(0.1),
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
                      Text(
                        'Pay with GCash QR',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete your payment using GCash QR code',
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
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.table == 'advance_orders' ? 'Total Price' : 'Payment Amount',
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
                      SizedBox(height: 24),
                      // GCash QR Code Image
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.width * 0.9,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/newgcash.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.grey.shade300),
                                    SizedBox(height: 12),
                                    Text('Scan QR Code', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Amount Deposit display for advance orders
                      if (widget.table == 'advance_orders') ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount Deposit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'PHP ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      widget.depositAmount.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        // Upload receipt button
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload your receipt',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              if (_receiptImageUrl != null) ...[
                                Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryColor),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _receiptImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Receipt uploaded successfully',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: _pickReceiptImage,
                                  icon: Icon(Icons.upload_file),
                                  label: Text('Choose Receipt Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(double.infinity, 48),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Supported formats: PNG, JPG, JPEG',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      // Upload receipt for reservations (Event Place)
                      if (widget.table == 'reservations') ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload your receipt',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              if (_receiptImageUrl != null) ...[
                                Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryColor),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _receiptImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Receipt uploaded successfully',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: _pickReceiptImage,
                                  icon: Icon(Icons.upload_file),
                                  label: Text('Choose Receipt Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(double.infinity, 48),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Supported formats: PNG, JPG, JPEG',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                        ),
                        child: CheckboxListTile(
                          value: _isConfirmed,
                          onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                          title: const Text(
                            'I confirm that I have successfully transferred the payment via GCash.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          activeColor: AppTheme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (widget.table == 'reservations') ...[
                        SizedBox(height: 24),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
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
                                      'Open your GCash app',
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
                                      'Scan the QR code',
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
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isConfirmed ? _handlePaymentSuccess : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _isConfirmed ? AppTheme.primaryColor : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _isConfirmed ? AppTheme.primaryColor : Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          'I already completed the payment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConfirmed ? AppTheme.primaryColor : Colors.grey,
                          ),
                        ),
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
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
