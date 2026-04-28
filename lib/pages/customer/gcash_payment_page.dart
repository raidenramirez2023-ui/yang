import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
  String? _receiptImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();

  // No initState needed - simplified flow

  Uint8List? _receiptBytes;

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // Validate file extension (avoiding synchronous mimeType crash)
        final extension = image.name.split('.').last.toLowerCase();
        final allowedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'];
        if (!allowedExtensions.contains(extension)) {
          _showErrorDialog('Please select a valid image file (${allowedExtensions.join(', ')}).');
          return;
        }

        final bytes = await image.readAsBytes();
        setState(() {
          _receiptBytes = bytes;
          _isLoading = true; // Start loading immediately for feedback
        });

        // Upload to Supabase storage
        await _uploadReceiptToSupabase(image.name, bytes);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _uploadReceiptToSupabase(String originalName, Uint8List bytes) async {
    try {
      final extension = originalName.split('.').last;
      final fileName = 'gcash_receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'receipts/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

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

    if (_receiptImageUrl == null) {
      _showErrorDialog('Please upload your GCash receipt.');
      return;
    }

    setState(() {
      _paymentCompleted = true;
    });

    try {
      final depositAmount = widget.depositAmount;

      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: widget.table == 'reservations' ? 'deposit_paid' : 'pending_verification',
        table: widget.table,
        paymentAmount: depositAmount,
        paymentReference: 'GCASH_${DateTime.now().millisecondsSinceEpoch}',
        receiptUrl: _receiptImageUrl,
      );

      if (!success) {
        throw Exception('Failed to update payment status');
      }

      await _sendPaymentConfirmationEmail(depositAmount);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Payment successful but update failed: $e');
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
      debugPrint('Error sending email: $e');
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
        content: Text('Your GCash payment is pending admin approval. Once verified, your order will be processed.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back
              widget.onPaymentSuccess();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
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
        title: Row(children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 8), Text('Payment Issue')]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK'))],
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Payment?'),
        content: Text('Are you sure you want to cancel? Your order will not be processed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('No')),
          TextButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: Text('Yes, Cancel')),
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
        leading: IconButton(icon: Icon(Icons.close), onPressed: _showCancelConfirmationDialog),
      ),
      body: _paymentCompleted
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 64), Text('Payment Successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Pay with GCash QR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  SizedBox(height: 20),
                  Text('Amount: PHP ${widget.depositAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 24),
                  Image.asset('assets/images/newgcash.png', height: 300, errorBuilder: (_, __, ___) => Icon(Icons.qr_code, size: 200, color: Colors.grey)),
                  SizedBox(height: 24),
                  if (_receiptBytes != null || _receiptImageUrl != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _receiptBytes != null
                              ? Image.memory(_receiptBytes!, height: 180, fit: BoxFit.cover)
                              : Image.network(_receiptImageUrl!, height: 180, fit: BoxFit.cover),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _receiptImageUrl != null ? Icons.check_circle : Icons.sync,
                              color: _receiptImageUrl != null ? Colors.green : Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _receiptImageUrl != null ? 'Receipt Uploaded' : 'Uploading to server...',
                              style: TextStyle(
                                color: _receiptImageUrl != null ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_receiptImageUrl == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: LinearProgressIndicator(),
                          ),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _pickReceiptImage,
                          icon: Icon(Icons.refresh, size: 16),
                          label: Text('Change Image', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _pickReceiptImage,
                      icon: Icon(Icons.upload),
                      label: Text('Upload Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                    ),
                  SizedBox(height: 24),
                  CheckboxListTile(
                    value: _isConfirmed,
                    onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                    title: Text('I confirm I have sent the payment.'),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isConfirmed && _receiptImageUrl != null && !_isLoading) ? _handlePaymentSuccess : null,
                    child: _isLoading ? CircularProgressIndicator() : Text('Confirm Payment'),
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }
}
