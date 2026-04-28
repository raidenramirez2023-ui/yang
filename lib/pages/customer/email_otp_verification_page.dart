import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

/// Arguments passed to this page from the registration page.
class OtpVerificationArgs {
  final String email;
  final String firstName;
  final String lastName;
  final String phone;

  const OtpVerificationArgs({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });
}

/// Magic Link "Check Your Email" waiting screen.
/// After the user clicks the verification link in their email, the Supabase
/// SDK fires an onAuthStateChange event (signedIn). We listen for that event
/// here and complete the registration (DB insert) automatically.
class EmailOtpVerificationPage extends StatefulWidget {
  final OtpVerificationArgs args;

  const EmailOtpVerificationPage({super.key, required this.args});

  @override
  State<EmailOtpVerificationPage> createState() =>
      _EmailOtpVerificationPageState();
}

class _EmailOtpVerificationPageState extends State<EmailOtpVerificationPage>
    with SingleTickerProviderStateMixin {
  // Auth state listener subscription
  StreamSubscription<AuthState>? _authSubscription;

  bool _isResending = false;
  bool _isSuccess = false;
  bool _isProcessing = false;

  // Resend cooldown timer
  int _resendSecondsRemaining = 60;
  Timer? _resendTimer;

  // Pulse animation for the email icon
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupAuthListener();

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _resendTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Listen for the magic link callback — fires when user clicks the link
  /// in their email and the browser/app processes the session token.
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        final session = data.session;

        debugPrint('🔔 Auth event: $event | Session: ${session?.user.id}');

        // signedIn event fires when the magic link is clicked and processed
        if (event == AuthChangeEvent.signedIn && session != null && !_isSuccess) {
          await _completeRegistration(session);
        }
      },
    );
  }

  /// Called when Supabase confirms the magic link was clicked.
  /// Inserts the user into public.users and navigates to login.
  Future<void> _completeRegistration(Session session) async {
    if (_isProcessing) return;
    if (mounted) setState(() => _isProcessing = true);

    try {
      debugPrint('✅ Magic link verified! Completing registration...');

      // Insert user into the public.users table now that they are verified
      await Supabase.instance.client.from('users').insert({
        'email': widget.args.email,
        'firstname': widget.args.firstName,
        'lastname': widget.args.lastName,
        'phone': widget.args.phone,
        'role': 'customer',
        'is_approved': true, // Auto-approved via email verification
      });

      debugPrint('✅ User inserted into public.users. Signing out...');

      // Sign out so they properly go through the login page
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isProcessing = false;
        });

        // Show success state, then redirect to login
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('DB Error during registration completion: ${e.message}');
      if (mounted) {
        setState(() => _isProcessing = false);
        // If user already in DB (e.g., duplicate from earlier test), still proceed
        if (e.code == '23505') {
          await Supabase.instance.client.auth.signOut();
          setState(() => _isSuccess = true);
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        } else {
          _showSnackBar('Error completing registration: ${e.message}',
              isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error completing registration: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('An error occurred. Please try again.', isError: true);
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSecondsRemaining > 0) {
          _resendSecondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendEmail() async {
    if (_resendSecondsRemaining > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.args.email,
      );

      if (mounted) {
        _startResendTimer();
        _showSnackBar('A new verification link has been sent to your email.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to resend. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: (_isSuccess || _isProcessing)
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppTheme.darkGrey, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isSuccess
              ? _buildSuccessView()
              : _isProcessing
                  ? _buildProcessingView()
                  : _buildWaitingView(),
        ),
      ),
    );
  }

  // ─── Views ───────────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.successGreen,
                size: 68,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Email Verified!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account has been created successfully.\nRedirecting you to login...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.mediumGrey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppTheme.successGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      key: const ValueKey('processing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Verifying your email...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    // Mask email: ke****@gmail.com
    final email = widget.args.email;
    final atIndex = email.indexOf('@');
    final maskedEmail = atIndex > 2
        ? '${email.substring(0, 2)}${'*' * (atIndex - 2)}${email.substring(atIndex)}'
        : email;

    return SingleChildScrollView(
      key: const ValueKey('waiting'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Animated envelope icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.primaryColor.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.forward_to_inbox_rounded,
                size: 56,
                color: AppTheme.primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Check Your Email',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.mediumGrey,
                  height: 1.7,
                ),
                children: [
                  const TextSpan(text: 'We sent a verification link to\n'),
                  TextSpan(
                    text: maskedEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '\n\nOpen your email and click the link to\ncomplete your registration.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Steps guide
          _buildStepCard(
            icon: Icons.email_outlined,
            step: '1',
            text: 'Open your email inbox',
          ),
          const SizedBox(height: 10),
          _buildStepCard(
            icon: Icons.link_rounded,
            step: '2',
            text: 'Click the "Confirm your email" link',
          ),
          const SizedBox(height: 10),
          _buildStepCard(
            icon: Icons.login_rounded,
            step: '3',
            text: 'Come back and log in to your account',
          ),

          const SizedBox(height: 36),

          // Resend section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  "Didn't receive an email?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Check your Spam or Junk folder first.',
                  style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: (_resendSecondsRemaining > 0 || _isResending)
                        ? null
                        : _resendEmail,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _resendSecondsRemaining > 0
                            ? Colors.grey.shade300
                            : AppTheme.primaryColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : Text(
                            _resendSecondsRemaining > 0
                                ? 'Resend in ${_resendSecondsRemaining}s'
                                : 'Resend Verification Email',
                            style: TextStyle(
                              color: _resendSecondsRemaining > 0
                                  ? AppTheme.mediumGrey
                                  : AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Security note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              const Text(
                'The verification link expires in 1 hour.',
                style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required String step,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.darkGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
