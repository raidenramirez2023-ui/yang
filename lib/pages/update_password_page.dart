import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class UpdatePasswordPage extends StatefulWidget {
  final String email;
  
  const UpdatePasswordPage({
    super.key,
    required this.email,
  });

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verify the 6-digit OTP code against the user's email
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );

      // 2. If verification is successful, the user is logged in. Now update their password directly.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // After successful password update, redirect to login page
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.message;
        if (e.message.contains('Token has expired or is invalid')) {
           errorMsg = 'The 8-digit code is incorrect or expired. Please request a new one.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
            content: Text('Error: $e'),
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
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 40, tablet: 48, desktop: 56),
                      color: AppTheme.primaryRed,
                    ),
                  ),

                  ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),

                  Text(
                    'Update Password',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24, tablet: 28, desktop: 32),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 12, desktop: 16),

                  Text(
                    'We\'ve sent an 8-digit code to ${widget.email}\n\nEnter the code and your new password below.',
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
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: '8-Digit Code',
                            hintText: 'Enter 8-digit code from email',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the 8-digit code';
                            }
                            if (value.trim().length != 8) {
                              return 'Code must be exactly 8 digits';
                            }
                            return null;
                          },
                        ),

                        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

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

                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveUtils.getResponsiveFontSize(context, mobile: 48, tablet: 52, desktop: 56),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
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
                                      Text('Updating...'),
                                    ],
                                  )
                                : const Text(
                                    'Verify Code & Update Password',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),

                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveUtils.getResponsiveFontSize(context, mobile: 48, tablet: 52, desktop: 56),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: BorderSide(color: AppTheme.primaryRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
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
}
