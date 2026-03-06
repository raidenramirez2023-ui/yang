import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:postgrest/postgrest.dart';

class CustomerRegistrationPage extends StatefulWidget {
  const CustomerRegistrationPage({super.key});

  @override
  State<CustomerRegistrationPage> createState() => _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _isRedirecting = false; // Flag to prevent multiple redirects

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com', // Replace with your actual client ID
  );

  @override
  void initState() {
    super.initState();
    
    // 1. Check if we already have a session (e.g. after a redirect back to this page)
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession != null) {
      debugPrint('OAuth: Initial session detected, redirecting...');
      _handleOAuthSuccess(initialSession);
    }

    // 2. Listen for auth state changes for real-time redirects
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        debugPrint('OAuth: Signed in event detected, redirecting...');
        _handleOAuthSuccess(data.session!);
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> handleRegistration() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(
        "Please fill in all fields",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar(
        "Please enter a valid email address",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    if (password.length < 6) {
      _showSnackBar(
        "Password must be at least 6 characters",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar(
        "Passwords do not match",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    if (!_agreeToTerms) {
      _showSnackBar(
        "Please agree to the terms and conditions",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create user in Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': 'customer',
        },
      );

      if (authResponse.user != null) {
        // Immediately sign in to activate the account
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        // Customer record created via auth metadata only
        print('=== CUSTOMER CREATED VIA AUTH ===');
        print('User ID: ${authResponse.user!.id}');
        print('Email: $email');
        print('Name: $name');
        print('SUCCESS: Customer account ready');
        
        _showSnackBar(
          "Registration successful! Account is now ready to use.",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        // Navigate to customer dashboard after successful registration
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/customer-dashboard');
        }
      }
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message.toLowerCase()) {
        case 'user already registered':
          errorMessage = 'An account with this email already exists';
          break;
        case 'invalid email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'password too short':
          errorMessage = 'Password must be at least 6 characters';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
      }
      _showSnackBar(errorMessage, Colors.red.shade700, Icons.error_outline);
    } on PostgrestException catch (e) {
      String errorMessage;
      if (e.code == '23505') {
        errorMessage = 'An account with this email already exists in our system';
      } else if (e.message.contains('duplicate')) {
        errorMessage = 'This email is already registered. Please use a different email.';
      } else {
        errorMessage = 'Database error: ${e.message}';
      }
      _showSnackBar(errorMessage, Colors.red.shade700, Icons.error_outline);
    } catch (e) {
      _showSnackBar(
        "An error occurred during registration: $e",
        Colors.red.shade700,
        Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Clear existing session before starting new Google login to force fresh interaction
        await Supabase.instance.client.auth.signOut();
        
        await Supabase.instance.client.auth.signInWithOAuth(
          Provider.google,
          redirectTo: Uri.base.origin,
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        // Sign out first to ensure account picker is shown (fixes auto-selection of previous account)
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        
        final googleUser = await _googleSignIn.signIn();
        final googleAuth = await googleUser?.authentication;
        final accessToken = googleAuth?.accessToken;
        final idToken = googleAuth?.idToken;

        if (accessToken == null || idToken == null) {
          throw 'Google Sign-In failed: Missing tokens';
        }

        await Supabase.instance.client.auth.signInWithIdToken(
          provider: Provider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Google Sign-In Error: $e", Colors.red.shade700, Icons.error_outline);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOAuthSuccess(Session session) async {
    if (_isRedirecting) return;
    
    final email = session.user.email;
    if (email == null) return;

    _isRedirecting = true; // Mark as redirecting to prevent race conditions
    try {
      // Check if user exists in the users table
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', email)
          .maybeSingle();

      final metadata = session.user.userMetadata ?? {};
      final name = metadata['full_name']?.toString() ?? metadata['name']?.toString() ?? 'Customer';

      if (userResponse == null) {
        // Create new user with 'customer' role
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'role': 'customer',
          'name': name,
        });
      } else {
        // Update name if user exists (optional, but keeps it in sync)
        await Supabase.instance.client
            .from('users')
            .update({'name': name})
            .eq('email', email);
            
        // Check if existing user is NOT a customer
        String userRole = userResponse['role']?.toString().toLowerCase() ?? 'customer';
        if (userRole != 'customer') {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            _showSnackBar(
              "Google Sign-In is only allowed for customer accounts.",
              Colors.red.shade700,
              Icons.block,
            );
          }
          return;
        }
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/customer-dashboard');
      }
    } catch (e) {
      print('Error in _handleOAuthSuccess: $e');
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedirecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryRed),
              SizedBox(height: 16),
              Text('Syncing with Google...', style: TextStyle(color: AppTheme.primaryRed)),
            ],
          ),
        ),
      );
    }

    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Customer Registration'),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Full image background (50%)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/yc.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Right side - White background (50%)
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildRegistrationForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mobile-logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Create Customer Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color.fromARGB(255, 119, 36, 36),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Registration Form
              _buildRegistrationForm(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Name Field
        Text(
          'Full Name',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nameController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Email Field
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password Field
        Text(
          'Password',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Create a password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible 
                  ? Icons.visibility_outlined 
                  : Icons.visibility_off_outlined,
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
        ),
        const SizedBox(height: 12),

        // Confirm Password Field
        Text(
          'Confirm Password',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Confirm your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible 
                  ? Icons.visibility_outlined 
                  : Icons.visibility_off_outlined,
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
        ),
        const SizedBox(height: 16),

        // Terms and Conditions Checkbox
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: _isLoading ? null : (bool? value) {
                setState(() {
                  _agreeToTerms = value ?? false;
                });
              },
              activeColor: AppTheme.primaryRed,
            ),
            Expanded(
              child: Text(
                'I agree to the Terms and Conditions and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Register Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleRegistration,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Account'),
          ),
        ),
        const SizedBox(height: 24),

        // OR Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 24),

        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            icon: SvgPicture.network(
              'https://www.svgrepo.com/show/355037/google.svg',
              width: 20,
              height: 20,
            ),
            label: const Text(
              'Sign up with Google',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Back to Login Link
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _isLoading ? null : () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Already have an account? Sign In',
              style: TextStyle(
                color: AppTheme.primaryRed,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}