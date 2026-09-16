import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PayMongoPaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String? paymentLinkId;
  final String reservationId;
  final double paymentAmount;
  final VoidCallback onPaymentSuccess;
  final String table;
  final double? totalPrice;

  const PayMongoPaymentPage({
    super.key,
    required this.paymentUrl,
    this.paymentLinkId,
    required this.reservationId,
    required this.paymentAmount,
    required this.onPaymentSuccess,
    this.table = 'reservations',
    this.totalPrice,
  });

  @override
  State<PayMongoPaymentPage> createState() => _PayMongoPaymentPageState();
}

class _PayMongoPaymentPageState extends State<PayMongoPaymentPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _paymentCompleted = false;
  final ReservationService _reservationService = ReservationService();
  final EmailNotificationService _emailService = EmailNotificationService();
  final ImagePicker _imagePicker = ImagePicker();
  String? _receiptImageUrl;
  Uint8List? _receiptBytes;
  bool _isUploading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static final _moneyFmt = NumberFormat('#,##0.00', 'en_PH');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _launchPayment();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  Future<void> _uploadReceiptToSupabase(
      String originalName, Uint8List bytes) async {
    try {
      final extension = originalName.split('.').last;
      final fileName =
          'paymongo_receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'receipts/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes,
              fileOptions: const FileOptions(upsert: true));

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
      _showErrorDialog('Please upload your payment receipt first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      const String paymentStatus = 'pending_verification';

      final success = await _reservationService.updatePaymentStatus(
        id: widget.reservationId,
        paymentStatus: paymentStatus,
        table: widget.table,
        paymentAmount: widget.paymentAmount,
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
          depositAmount: widget.paymentAmount,
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E4A42), Color(0xFF14332E)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14332E).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFFD9A441), size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Receipt Submitted!',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your payment is being reviewed by our admin team. You'll be notified once verified.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      widget.onPaymentSuccess();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Got it!',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.5),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style:
                      TextButton.styleFrom(foregroundColor: const Color(0xFF14332E)),
                  child: Text('OK',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool receiptReady = _receiptImageUrl != null && !_isUploading;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14332E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Secure Payment',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 14 : 20,
            vertical: isSmallScreen ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner Card
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 18 : 26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14332E), Color(0xFF1A3D35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14332E).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: isSmallScreen ? 62 : 72,
                        height: isSmallScreen ? 62 : 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9A441).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD9A441).withValues(alpha: 0.4),
                              width: 2),
                        ),
                        child: Icon(Icons.open_in_browser_rounded,
                            color: const Color(0xFFD9A441),
                            size: isSmallScreen ? 28 : 34),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment In Progress',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete the payment in your browser,\nthen upload your receipt below.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 14 : 20,
                          vertical: isSmallScreen ? 10 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFD9A441).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payments_rounded,
                              color: Color(0xFFD9A441), size: 18),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'AMOUNT DUE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFD9A441),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${String.fromCharCode(0x20B1)} ${_moneyFmt.format(widget.paymentAmount)}',
                                    style: GoogleFonts.inter(
                                      fontSize: isSmallScreen ? 22 : 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Steps
              _buildStepRow(
                  step: 1,
                  icon: Icons.language_rounded,
                  label: 'Pay in browser',
                  done: true),
              _buildStepConnector(),
              _buildStepRow(
                  step: 2,
                  icon: Icons.upload_rounded,
                  label: 'Upload your receipt screenshot',
                  done: receiptReady,
                  active: !receiptReady),
              _buildStepConnector(),
              _buildStepRow(
                  step: 3,
                  icon: Icons.verified_rounded,
                  label: 'Admin verifies & confirms',
                  done: _paymentCompleted),
              const SizedBox(height: 28),

              // Receipt upload
              if (_receiptBytes != null) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: receiptReady
                          ? const Color(0xFF14332E).withValues(alpha: 0.4)
                          : const Color(0xFFD9A441).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14332E).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.memory(_receiptBytes!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover),
                        if (_isUploading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            height: 220,
                            width: double.infinity,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFD9A441), strokeWidth: 2.5),
                            ),
                          ),
                        if (receiptReady)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            color: const Color(0xFF14332E).withValues(alpha: 0.85),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFFD9A441), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Receipt attached & uploaded',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isUploading ? null : _pickReceiptImage,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Change Receipt'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B)),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _pickReceiptImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFD9A441).withValues(alpha: 0.4),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14332E).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9A441).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.upload_file_rounded,
                              color: Color(0xFFD9A441), size: 26),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to Upload Receipt',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF14332E)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Screenshot from your browser & upload here',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              AnimatedOpacity(
                opacity: receiptReady ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (receiptReady && !_isLoading)
                        ? _handleManualPaymentSubmission
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF14332E),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: receiptReady ? 4 : 0,
                      shadowColor:
                          const Color(0xFF14332E).withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Color(0xFFD9A441), strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 20, color: Color(0xFFD9A441)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    receiptReady
                                        ? 'Submit for Verification'
                                        : 'Upload Receipt First',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Secondary actions
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildTextAction(
                    icon: Icons.open_in_new_rounded,
                    label: 'Reopen Payment Page',
                    onTap: _launchPayment,
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: const Color(0xFFCBD5E1),
                  ),
                  _buildTextAction(
                    icon: Icons.arrow_back_rounded,
                    label: 'Go Back',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required int step,
    required IconData icon,
    required String label,
    bool done = false,
    bool active = false,
  }) {
    final Color stepColor = done
        ? const Color(0xFF14332E)
        : active
            ? const Color(0xFFD9A441)
            : const Color(0xFFCBD5E1);
    final Color textColor =
        done || active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF14332E)
                : active
                    ? const Color(0xFFD9A441).withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(color: stepColor, width: 1.5),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 16,
            color: done
                ? const Color(0xFFD9A441)
                : active
                    ? const Color(0xFFD9A441)
                    : const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: done || active ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
        if (done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Done',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14532D))),
          ),
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD9A441).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Pending',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD9A441))),
          ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildTextAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
