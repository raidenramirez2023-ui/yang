import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/sms_service.dart';
import 'package:yang_chow/utils/app_theme.dart';

/// Modal dialog that guides customers to verify their mobile number via PhilSMS OTP
class PhoneOtpModal extends StatefulWidget {
  final String? initialPhone;
  final VoidCallback onVerified;
  final String? customTitle;
  final String? customSubtitle;

  const PhoneOtpModal({
    super.key,
    this.initialPhone,
    required this.onVerified,
    this.customTitle,
    this.customSubtitle,
  });

  /// Convenient static helper to show the Phone OTP Modal anywhere
  static Future<void> show(
    BuildContext context, {
    String? initialPhone,
    required VoidCallback onVerified,
    String? customTitle,
    String? customSubtitle,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PhoneOtpModal(
        initialPhone: initialPhone,
        onVerified: onVerified,
        customTitle: customTitle,
        customSubtitle: customSubtitle,
      ),
    );
  }

  @override
  State<PhoneOtpModal> createState() => _PhoneOtpModalState();
}

class _PhoneOtpModalState extends State<PhoneOtpModal> {
  final SmsService _smsService = SmsService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // Step 1 = Confirm/Edit Phone & Request OTP, Step 2 = Enter & Verify OTP
  int _currentStep = 1;

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isEditingPhone = false;
  String? _errorMessage;

  // Cooldown timer for resend
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    String phone = widget.initialPhone ?? '';
    if (phone.isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      phone = user?.userMetadata?['phone'] ?? '';
    }
    _phoneController.text = phone;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11 || !phone.startsWith('09')) {
      setState(() {
        _errorMessage = 'Please enter a valid 11-digit mobile number (09XXXXXXXXX).';
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final res = await _smsService.sendOtp(phone);

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isSendingOtp = false;
        _currentStep = 2;
        _isEditingPhone = false;
        _errorMessage = null;
      });
      _startCooldown();
    } else {
      setState(() {
        _isSendingOtp = false;
        _errorMessage = res['message'] ?? 'Failed to send OTP code. Please check API settings.';
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    final res = await _smsService.verifyOtp(
      rawPhone: _phoneController.text.trim(),
      otpCode: otp,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _isVerifyingOtp = false);
      Navigator.of(context).pop(); // close modal
      widget.onVerified(); // execute callback (e.g. proceed to reservation)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Mobile number verified successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF164438),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = res['message'] ?? 'Verification failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Close and Icon Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warmGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_rounded,
                      color: Color(0xFFC9922E),
                      size: 26,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title & Subtitle
              Text(
                widget.customTitle ??
                    (_currentStep == 1
                        ? 'Verify Your Mobile Number'
                        : 'Enter Verification Code'),
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2B24),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.customSubtitle ??
                    (_currentStep == 1
                        ? 'To ensure you receive critical SMS updates regarding your reservation status, advance orders, and payment alerts, please authenticate your mobile number.'
                        : 'We sent a 6-digit code to ${_phoneController.text}. Please enter it below to complete verification.'),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // STEP 1 CONTENT: Confirm / Edit Phone
              if (_currentStep == 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mobile Number',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() => _isEditingPhone = !_isEditingPhone);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _isEditingPhone ? Icons.check : Icons.edit_outlined,
                                  size: 14,
                                  color: const Color(0xFFC9922E),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isEditingPhone ? 'Done' : 'Change',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFC9922E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _isEditingPhone
                          ? TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              autofocus: true,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F2B24),
                              ),
                              decoration: const InputDecoration(
                                hintText: '09XXXXXXXXX',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            )
                          : Text(
                              _phoneController.text.isNotEmpty
                                  ? _phoneController.text
                                  : 'No mobile number set',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F2B24),
                                letterSpacing: 0.5,
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Button: Send OTP
                ElevatedButton(
                  onPressed: _isSendingOtp ? null : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: const Color(0xFFFFFAEB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSendingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmGold),
                          ),
                        )
                      : Text(
                          'Send Verification Code',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ],

              // STEP 2 CONTENT: Enter OTP Code
              if (_currentStep == 2) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: const Color(0xFF0F2B24),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFC9922E),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Resend Cooldown row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = 1;
                          _errorMessage = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Change Number',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    _cooldownSeconds > 0
                        ? Text(
                            'Resend in ${_cooldownSeconds}s',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : TextButton(
                            onPressed: _isSendingOtp ? null : _handleSendOtp,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Resend Code',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC9922E),
                              ),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 18),

                // Button: Verify Code
                ElevatedButton(
                  onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: const Color(0xFFFFFAEB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifyingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmGold),
                          ),
                        )
                      : Text(
                          'Verify Code & Proceed',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
