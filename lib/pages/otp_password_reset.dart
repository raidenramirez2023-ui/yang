import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class OtpPasswordResetPage extends StatefulWidget {
  final String email;
  
  const OtpPasswordResetPage({
    super.key,
    required this.email,
  });

  @override
  State<OtpPasswordResetPage> createState() => _OtpPasswordResetPageState();
}

class _OtpPasswordResetPageState extends State<OtpPasswordResetPage> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _passwordReset = false;
  bool _otpVerified = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter 8-digit code'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify the OTP code
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpVerified = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code verified! Please set your new password.'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } on AuthException catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid code. Please try again.'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying code: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update the user's password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _passwordReset = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting password: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code resent! Check your email.'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending code: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (_passwordReset) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 400,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.getResponsiveFontSize(context, mobile: 20, tablet: 24, desktop: 28),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 40, tablet: 48, desktop: 56),
                        color: AppTheme.successGreen,
                      ),
                    ),
                    
                    ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                    
                    Text(
                      'Password Reset Successfully!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24, tablet: 28, desktop: 32),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
                    
                    Text(
                      'Your password has been reset successfully.\nYou can now login with your new password.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.mediumGrey,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    ResponsiveUtils.verticalSpace(context, mobile: 32, tablet: 40, desktop: 48),
                    
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveUtils.getResponsiveFontSize(context, mobile: 48, tablet: 52, desktop: 56),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Back to Login',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveFontSize(context, mobile: 20, tablet: 24, desktop: 28),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _otpVerified ? Icons.lock_reset : Icons.email_outlined,
                      size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 40, tablet: 48, desktop: 56),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                  
                  Text(
                    _otpVerified ? 'Set New Password' : 'Enter Verification Code',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24, tablet: 28, desktop: 32),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 12, desktop: 16),
                  
                  Text(
                    _otpVerified 
                      ? 'Enter your new password below.'
                      : 'We sent an 8-digit code to ${widget.email}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.mediumGrey,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 32, tablet: 40, desktop: 48),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_otpVerified) ...[
                          // OTP Input
                          TextFormField(
                            controller: _otpController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            decoration: InputDecoration(
                              labelText: '8-Digit Code',
                              hintText: 'Enter verification code',
                              prefixIcon: const Icon(Icons.email_outlined),
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the verification code';
                              }
                              if (value.length != 8) {
                                return 'Code must be 8 digits';
                              }
                              return null;
                            },
                          ),
                          
                          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
                          
                          // Verify Code Button
                          SizedBox(
                            width: double.infinity,
                            height: ResponsiveUtils.getResponsiveFontSize(context, mobile: 48, tablet: 52, desktop: 56),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Verifying...'),
                                      ],
                                    )
                                  : const Text(
                                      'Verify Code',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                          
                          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
                          
                          // Resend Code
                          TextButton(
                            onPressed: _isLoading ? null : _resendCode,
                            child: Text(
                              'Resend Code',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Password Fields (after OTP verified)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              hintText: 'Enter new password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              hintText: 'Confirm new password',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),

                          // Reset Password Button
                          SizedBox(
                            width: double.infinity,
                            height: ResponsiveUtils.getResponsiveFontSize(context, mobile: 48, tablet: 52, desktop: 56),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Resetting...'),
                                      ],
                                    )
                                  : const Text(
                                      'Reset Password',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
