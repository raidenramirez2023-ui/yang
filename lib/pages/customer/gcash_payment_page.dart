import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

class GCashPaymentPage extends StatefulWidget {
  final String reservationId;
  final double depositAmount;
  final VoidCallback onPaymentSuccess;
  final String table; // 'reservations' or 'advance_orders'
  final double? totalPrice; // Used to detect full payment

  const GCashPaymentPage({
    super.key,
    required this.reservationId,
    required this.depositAmount,
    required this.onPaymentSuccess,
    this.table = 'reservations',
    this.totalPrice,
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

  Uint8List? _receiptBytes;

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final extension = image.name.split('.').last.toLowerCase();
        final allowedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'];
        if (!allowedExtensions.contains(extension)) {
          _showErrorDialog('Please select a valid image file (${allowedExtensions.join(', ')}).');
          return;
        }

        final bytes = await image.readAsBytes();
        setState(() {
          _receiptBytes = bytes;
          _isLoading = true;
        });

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

      // Always send pending_verification — admin must verify receipt before confirming
      final String paymentStatus = 'pending_verification';

      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: paymentStatus,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Payment Pending Approval',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Your GCash payment receipt has been submitted for admin verification.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkGrey),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              widget.onPaymentSuccess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Got it!', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 24),
            const SizedBox(width: 8),
            Text('Payment Issue', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Payment?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel? Your order will not be processed.', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('No', style: GoogleFonts.inter(color: AppTheme.mediumGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Yes, Cancel', style: GoogleFonts.inter(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('GCash Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.darkGrey),
          onPressed: _showCancelConfirmationDialog,
        ),
      ),
      body: _paymentCompleted
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Payment Submitted!',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Amount Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'AMOUNT TO PAY',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${widget.depositAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // GCash QR Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.foodCardDecoration(),
                    child: Column(
                      children: [
                        Text(
                          'Scan GCash QR Code',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/newgcash.png',
                            height: 260,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: AppTheme.lightGrey,
                              child: const Icon(Icons.qr_code_2_rounded, size: 100, color: AppTheme.mediumGrey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Receipt Upload Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.foodCardDecoration(),
                    child: Column(
                      children: [
                        Text(
                          'Proof of Payment',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                        ),
                        const SizedBox(height: 12),
                        if (_receiptBytes != null || _receiptImageUrl != null)
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _receiptBytes != null
                                    ? Image.memory(_receiptBytes!, height: 180, fit: BoxFit.cover)
                                    : Image.network(_receiptImageUrl!, height: 180, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _receiptImageUrl != null ? Icons.check_circle_rounded : Icons.sync_rounded,
                                    color: _receiptImageUrl != null ? AppTheme.successGreen : AppTheme.warningOrange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _receiptImageUrl != null ? 'Receipt Uploaded' : 'Uploading to server...',
                                    style: GoogleFonts.inter(
                                      color: _receiptImageUrl != null ? AppTheme.successGreen : AppTheme.warningOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _isLoading ? null : _pickReceiptImage,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text('Change Receipt', style: GoogleFonts.inter(fontSize: 12)),
                              ),
                            ],
                          )
                        else
                          AnimatedTapScale(
                            onTap: _pickReceiptImage,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), style: BorderStyle.solid),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Upload GCash Receipt',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  CheckboxListTile(
                    value: _isConfirmed,
                    onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                    activeColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    title: Text(
                      'I confirm I have transferred the payment via GCash.',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                    ),
                  ),

                  const SizedBox(height: 20),

                  AnimatedTapScale(
                    onTap: (_isConfirmed && _receiptImageUrl != null && !_isLoading) ? _handlePaymentSuccess : null,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: (_isConfirmed && _receiptImageUrl != null && !_isLoading)
                            ? AppTheme.primaryGradient
                            : null,
                        color: (_isConfirmed && _receiptImageUrl != null && !_isLoading)
                            ? null
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: (_isConfirmed && _receiptImageUrl != null && !_isLoading)
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Confirm & Submit Receipt',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
