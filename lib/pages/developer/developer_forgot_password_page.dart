import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'developer_theme.dart';

class DeveloperForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const DeveloperForgotPasswordPage({super.key, this.initialEmail});

  @override
  State<DeveloperForgotPasswordPage> createState() =>
      _DeveloperForgotPasswordPageState();
}

class _DeveloperForgotPasswordPageState
    extends State<DeveloperForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Step 0: Request recovery email
  // Step 1: Enter OTP & New password
  // Step 2: Completed success screen
  int _currentStep = 0;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emailController.text.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _emailController.text = args;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleSendRecoveryEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your developer email.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // 1. Strict Role Verification: Ensure account exists and is an authorized developer
      final userRecord = await supabase
          .from('users')
          .select('role, firstname, lastname')
          .eq('email', email)
          .maybeSingle();

      final role = userRecord?['role']?.toString().toLowerCase() ?? '';

      if (role != 'developer') {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'ACCESS DENIED: Account "$email" is not registered with Developer role privileges.';
        });
        return;
      }

      // 2. Dispatch password reset via Supabase Auth
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo:
            kIsWeb ? '${Uri.base.origin}/developer/forgot-password' : null,
      );

      _startCooldown();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
          _successMessage =
              'Recovery instructions & verification code dispatched to "$email". Please check your inbox or spam folder.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Password recovery error: $e';
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (_resendCooldown > 0 || _isLoading) return;
    await _handleSendRecoveryEmail();
  }

  Future<void> _handleVerifyAndResetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code sent to your email.');
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter your new developer password.');
      return;
    }

    final hasUppercase = newPassword.contains(RegExp(r'[A-Z]'));
    final hasLowercase = newPassword.contains(RegExp(r'[a-z]'));
    final hasDigits = newPassword.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = newPassword.contains(
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
    );

    if (newPassword.length < 8 ||
        !hasUppercase ||
        !hasLowercase ||
        !hasDigits ||
        !hasSpecialCharacters) {
      setState(() => _errorMessage =
          'Password must be at least 8 characters long, contain an uppercase letter, lowercase letter, number, and special character.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Confirm password does not match the password you entered.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // 1. Verify OTP token for recovery
      await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );

      // 2. Update user's password
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 3. Clear temporary recovery session to enforce clean login
      await supabase.auth.signOut();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 2;
          _errorMessage = null;
          _successMessage = null;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeveloperTheme.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            decoration: DeveloperTheme.cardDecoration(
              borderRadius: 16,
              glow: true,
              glowColor: DeveloperTheme.accentIndigo,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Terminal / Key Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentIndigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DeveloperTheme.accentIndigo.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      _currentStep == 2
                          ? Icons.verified_user_rounded
                          : Icons.lock_reset_rounded,
                      color: _currentStep == 2
                          ? DeveloperTheme.accentEmerald
                          : DeveloperTheme.accentIndigo,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title & Subtitle
                Center(
                  child: Text(
                    _currentStep == 2
                        ? 'Password Reset Complete'
                        : 'Developer Password Recovery',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DeveloperTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _currentStep == 2
                        ? 'IT Developer Console Access Restored'
                        : 'Technical Maintenance & Security Portal',
                    style: DeveloperTheme.bodySmall(
                        color: DeveloperTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                // Security Protocol Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: _currentStep == 2
                            ? DeveloperTheme.accentEmerald
                            : DeveloperTheme.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentStep == 2
                            ? 'Security Clearance: Verified'
                            : 'Security Protocol: Developer Identity Required',
                        style: DeveloperTheme.monoText(
                          fontSize: 10,
                          color: DeveloperTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: DeveloperTheme.accentRose.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: DeveloperTheme.accentRose),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: DeveloperTheme.accentRose),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Success/Info Banner
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: DeveloperTheme.accentEmerald.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: DeveloperTheme.accentEmerald),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: DeveloperTheme.accentEmerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Step Contents
                if (_currentStep == 0) _buildStepRequestEmail(),
                if (_currentStep == 1) _buildStepVerifyOtpAndNewPassword(),
                if (_currentStep == 2) _buildStepCompleted(),

                const SizedBox(height: 20),

                // Return to Developer Login Link
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/developer/login');
                    },
                    icon: const Icon(Icons.arrow_back_rounded,
                        size: 16, color: DeveloperTheme.textMuted),
                    label: Text(
                      'Back to Developer Login',
                      style:
                          DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
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

  // ==========================================
  // Step 0: Input Developer Email
  // ==========================================
  Widget _buildStepRequestEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your authorized Developer Gmail address. We will verify your developer role privileges and send an OTP password recovery code.',
          style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        Text('Developer Email',
            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _isLoading ? null : _handleSendRecoveryEmail(),
          style: GoogleFonts.inter(fontSize: 14, color: DeveloperTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'yangchowit@gmail.com',
            hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
            prefixIcon: const Icon(Icons.badge_outlined,
                size: 18, color: DeveloperTheme.textMuted),
            filled: true,
            fillColor: DeveloperTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendRecoveryEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: DeveloperTheme.accentIndigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Send Recovery Code',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ==========================================
  // Step 1: Input OTP and Set New Password
  // ==========================================
  Widget _buildStepVerifyOtpAndNewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Email Confirmation Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DeveloperTheme.bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DeveloperTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined,
                  size: 16, color: DeveloperTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _emailController.text.trim(),
                  style: DeveloperTheme.monoText(
                    fontSize: 12,
                    color: DeveloperTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _currentStep = 0;
                  _errorMessage = null;
                }),
                child: Text(
                  'Change',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: DeveloperTheme.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // OTP Code Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Verification Code / OTP',
                style: DeveloperTheme.bodySmall(
                    color: DeveloperTheme.textSecondary)),
            if (_resendCooldown > 0)
              Text(
                'Resend in ${_resendCooldown}s',
                style: DeveloperTheme.monoText(
                  fontSize: 11,
                  color: DeveloperTheme.textMuted,
                ),
              )
            else
              InkWell(
                onTap: _isLoading ? null : _handleResendCode,
                child: Text(
                  'Resend Code',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: DeveloperTheme.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.text,
          style: DeveloperTheme.monoText(
            fontSize: 15,
            color: DeveloperTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Enter code from email',
            hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
            prefixIcon: const Icon(Icons.pin_rounded,
                size: 18, color: DeveloperTheme.textMuted),
            filled: true,
            fillColor: DeveloperTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // New Password Field
        Text('New Developer Password',
            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 14, color: DeveloperTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••••••',
            hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
            prefixIcon: const Icon(Icons.key_rounded,
                size: 18, color: DeveloperTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: DeveloperTheme.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: DeveloperTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
            ),
          ),
        ),

        // Live Requirements Checklist (Cyber Theme)
        Builder(
          builder: (_) {
            final pass = _passwordController.text;
            final hasMinLength = pass.length >= 8;
            final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
            final hasLowercase = pass.contains(RegExp(r'[a-z]'));
            final hasDigits = pass.contains(RegExp(r'[0-9]'));
            final hasSpecialCharacters = pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
            final isAllMet = hasMinLength && hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;

            Widget buildChip(String label, bool isMet) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: isMet ? DeveloperTheme.accentEmerald : DeveloperTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: DeveloperTheme.monoText(
                      fontSize: 10.5,
                      fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
                      color: isMet ? DeveloperTheme.accentEmerald : DeveloperTheme.textMuted,
                    ),
                  ),
                ],
              );
            }

            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DeveloperTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAllMet
                      ? DeveloperTheme.accentEmerald.withValues(alpha: 0.5)
                      : DeveloperTheme.borderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAllMet ? Icons.verified_user_rounded : Icons.shield_outlined,
                        size: 13,
                        color: isAllMet ? DeveloperTheme.accentEmerald : DeveloperTheme.accentCyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAllMet ? 'Strong Developer Password' : 'Password Requirements:',
                        style: DeveloperTheme.monoText(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAllMet ? DeveloperTheme.accentEmerald : DeveloperTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      buildChip('8+ Characters', hasMinLength),
                      buildChip('Uppercase (A-Z)', hasUppercase),
                      buildChip('Lowercase (a-z)', hasLowercase),
                      buildChip('Number (0-9)', hasDigits),
                      buildChip('Special Char (!@#\$...)', hasSpecialCharacters),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Confirm Password Field
        Text('Confirm New Developer Password',
            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) =>
              _isLoading ? null : _handleVerifyAndResetPassword(),
          style: GoogleFonts.inter(fontSize: 14, color: DeveloperTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••••••',
            hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
            prefixIcon: const Icon(Icons.check_circle_outline_rounded,
                size: 18, color: DeveloperTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: DeveloperTheme.textMuted,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            filled: true,
            fillColor: DeveloperTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
            ),
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyAndResetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: DeveloperTheme.accentIndigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Verify Code & Update Password',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ==========================================
  // Step 2: Completion Screen
  // ==========================================
  Widget _buildStepCompleted() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DeveloperTheme.accentEmerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: DeveloperTheme.accentEmerald.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: DeveloperTheme.accentEmerald, size: 48),
              const SizedBox(height: 12),
              Text(
                'Password Successfully Updated',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DeveloperTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your developer account credentials have been securely refreshed. You can now authenticate into the IT Developer Console.',
                style: DeveloperTheme.bodySmall(
                    color: DeveloperTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/developer/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: DeveloperTheme.accentEmerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sign In to Developer Console',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
