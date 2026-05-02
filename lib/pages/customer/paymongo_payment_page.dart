import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:yang_chow/services/paymongo_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class PayMongoPaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String? paymentLinkId;
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;
  final String table;

  const PayMongoPaymentPage({
    super.key,
    required this.paymentUrl,
    this.paymentLinkId,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
    this.table = 'reservations',
  });

  @override
  State<PayMongoPaymentPage> createState() => _PayMongoPaymentPageState();
}

class _PayMongoPaymentPageState extends State<PayMongoPaymentPage> {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();
  final ImagePicker _imagePicker = ImagePicker();
  String? _receiptImageUrl;
  Uint8List? _receiptBytes;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _launchPayment();
  }

  Future<void> _launchPayment() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorDialog('Failed to open payment page.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _receiptBytes = bytes;
          _isUploading = true;
        });
        await _uploadReceiptToSupabase(image.name, bytes);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _uploadReceiptToSupabase(String originalName, Uint8List bytes) async {
    try {
      final extension = originalName.split('.').last;
      final fileName = 'paymongo_receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'receipts/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      setState(() {
        _receiptImageUrl = imageUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorDialog('Failed to upload receipt: $e');
    }
  }

  void _handleManualPaymentSubmission() async {
    if (_paymentCompleted) return;

    if (_receiptImageUrl == null) {
      _showErrorDialog('Please upload your payment receipt.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: widget.table == 'reservations' ? 'deposit_paid' : 'pending_verification',
        table: widget.table,
        paymentAmount: widget.depositAmount,
        paymentReference: 'PAYMONGO_${widget.paymentLinkId}',
        receiptUrl: _receiptImageUrl,
      );

      if (success) {
        setState(() => _paymentCompleted = true);
        await _sendPaymentConfirmationEmail();
        if (mounted) _showSuccessDialog();
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      _showErrorDialog('Update failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      debugPrint('Email error: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 12), Text('Pending Approval')]),
        content: Text('Your payment is being reviewed by admin. Once verified, your order will be processed.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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
        title: Text('Issue'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Secure Payment'), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.credit_card_rounded, size: 80, color: AppTheme.primaryColor),
            SizedBox(height: 24),
            Text('Payment Redirected', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.errorRed)),
            SizedBox(height: 12),
            Text('Complete the payment in your browser and return here to upload your receipt.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.errorRed.withOpacity(0.1))),
              child: Column(
                children: [
                  Text('Payment Amount', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  SizedBox(height: 8),
                  Text('PHP ${widget.depositAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.errorRed)),
                ],
              ),
            ),
            SizedBox(height: 32),
            if (_receiptBytes != null)
              Column(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_receiptBytes!, height: 200, fit: BoxFit.cover)),
                  SizedBox(height: 12),
                  if (_isUploading) LinearProgressIndicator() else Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 8), Text('Receipt Attached', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                  TextButton.icon(onPressed: _isUploading ? null : _pickReceiptImage, icon: Icon(Icons.refresh), label: Text('Change Receipt')),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _pickReceiptImage,
                icon: Icon(Icons.upload_file),
                label: Text('Upload Receipt Screenshot'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_receiptImageUrl != null && !_isLoading) ? _handleManualPaymentSubmission : null,
              child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('I Completed Payment'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 56), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            SizedBox(height: 16),
            TextButton(onPressed: _launchPayment, child: Text('Reopen Payment Page')),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Go Back')),
          ],
        ),
      ),
    );
  }
}
