import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } on AuthException catch (e) {
      String errorMessage = 'An error occurred';
      
      switch (e.message) {
        case 'User not found':
          errorMessage = 'No account found with this email address';
          break;
        case 'Invalid email':
          errorMessage = 'The email address is not valid';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Try again later';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
                  // Logo/Icon
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 40,
                        tablet: 48,
                        desktop: 56,
                      ),
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                  
                  // Title
                  Text(
                    'Reset Password',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 12, desktop: 16),
                  
                  // Subtitle
                  Text(
                    _emailSent 
                        ? 'Check your email for reset instructions'
                        : 'Enter your email address and we\'ll send you a link to reset your password',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.mediumGrey,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 32, tablet: 40, desktop: 48),
                  
                  if (!_emailSent) ...[
                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 18,
                                  desktop: 20,
                                ),
                                vertical: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 16,
                                  desktop: 18,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email address';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          
                          ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                          
                          // Reset Button
                          SizedBox(
                            width: double.infinity,
                            height: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 48,
                              tablet: 52,
                              desktop: 56,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: ResponsiveUtils.getResponsiveIconSize(
                                            context,
                                            mobile: 16,
                                            tablet: 18,
                                            desktop: 20,
                                          ),
                                          height: ResponsiveUtils.getResponsiveIconSize(
                                            context,
                                            mobile: 16,
                                            tablet: 18,
                                            desktop: 20,
                                          ),
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        ResponsiveUtils.horizontalSpace(context, mobile: 12, tablet: 16, desktop: 20),
                                        Text(
                                          'Sending...',
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                              context,
                                              mobile: 14,
                                              tablet: 15,
                                              desktop: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Send Reset Link',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                                          context,
                                          mobile: 14,
                                          tablet: 15,
                                          desktop: 16,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Success Message
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.successGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.successGreen,
                            size: ResponsiveUtils.getResponsiveIconSize(
                              context,
                              mobile: 48,
                              tablet: 56,
                              desktop: 64,
                            ),
                          ),
                          ResponsiveUtils.verticalSpace(context, mobile: 12, tablet: 16, desktop: 20),
                          Text(
                            'Reset Email Sent!',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                            ),
                          ),
                          ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 12, desktop: 16),
                          Text(
                            'We\'ve sent a password reset link to ${_emailController.text}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.mediumGrey,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 13,
                                tablet: 14,
                                desktop: 15,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                    
                    // Back to Login Button
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 48,
                        tablet: 52,
                        desktop: 56,
                      ),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryRed,
                          side: BorderSide(color: AppTheme.primaryRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Back to Login',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 32, desktop: 40),
                  
                  // Help Text
                  if (!_emailSent)
                    Column(
                      children: [
                        Text(
                          'Need help?',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumGrey,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            ),
                          ),
                        ),
                        ResponsiveUtils.verticalSpace(context, mobile: 4, tablet: 6, desktop: 8),
                        Text(
                          'Contact your system administrator if you don\'t receive the email',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumGrey,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
