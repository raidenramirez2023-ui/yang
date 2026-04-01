import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class CustomerRegistrationPage extends StatefulWidget {
  const CustomerRegistrationPage({super.key});

  @override
  State<CustomerRegistrationPage> createState() =>
      _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  final bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidName(String name) {
    if (name.length < 2 || name.length > 50) return false;
    
    // Check for consecutive spaces, hyphens, or apostrophes
    if (RegExp(r"[\s\-'’]{2,}").hasMatch(name)) return false;
    
    // Check leading/trailing special characters
    if (RegExp(r"^[\s\-'’]|[\s\-'’]$").hasMatch(name)) return false;

    // Reject 3 or more identical consecutive characters (e.g. "Aaa", "Bbb")
    if (RegExp(r"(.)\1{2,}", caseSensitive: false).hasMatch(name)) return false;

    // Unicode letter support allowing spaces, hyphens, apostrophes
    return RegExp(r"^[\p{L}\p{M}\s\-'’]+$", unicode: true).hasMatch(name);
  }

  String _formatToTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().replaceAllMapped(
      RegExp(r"(^|[\s\-'’])(\p{L}\p{M}*)", unicode: true),
      (Match m) => '${m[1]}${m[2]!.toUpperCase()}'
    );
  }

  Future<void> handleRegistration() async {
    String rawFirstName = firstNameController.text.trim();
    String rawLastName = lastNameController.text.trim();
    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Formatting names to title case
    String firstName = _formatToTitleCase(rawFirstName);
    String lastName = _formatToTitleCase(rawLastName);

    // Update controllers to show title case (optional, but good for validation before insert below, though inserting works too)
    // Actually we will just pass formatted ones to insert

    // Validation
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar(
        "Please fill in all fields",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    if (!_isValidName(firstName)) {
      _showSnackBar(
        "Please enter a valid First Name (2-50 chars, letters/spaces/hyphens/apostrophes only)",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    if (!_isValidName(lastName)) {
      _showSnackBar(
        "Please enter a valid Last Name (2-50 chars, letters/spaces/hyphens/apostrophes only)",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    if (phone.length != 11 || !phone.startsWith('09') || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      _showSnackBar(
        "Please enter a valid phone number (11 digits, starting with 09)",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    final lowercaseEmail = email.toLowerCase();
    if (email != lowercaseEmail || 
        !(email.endsWith('@gmail.com') ||
          email.endsWith('@hotmail.com') ||
          email.endsWith('@outlook.com'))) {
      _showSnackBar(
        "Please enter a valid Email Address",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    // Password validation
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    if (password.length < 8 || !hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
      _showSnackBar(
        "Password must be at least 8 characters long, contain an uppercase letter, lowercase letter, number, and special character",
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
      // Name duplication validation
      final normalizedInputFirstName = firstName.replaceAll(' ', '').toLowerCase();
      final normalizedInputLastName = lastName.replaceAll(' ', '').toLowerCase();
      
      final existingUsers = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname, email');
          
      for (var user in existingUsers) {
        final existingFirstName = user['firstname']?.toString() ?? '';
        final existingLastName = user['lastname']?.toString() ?? '';
        final existingEmail = user['email']?.toString() ?? '';
        final normalizedExistingFirstName = existingFirstName.replaceAll(' ', '').toLowerCase();
        final normalizedExistingLastName = existingLastName.replaceAll(' ', '').toLowerCase();
        
        // Check for name duplication
        if (normalizedInputFirstName == normalizedExistingFirstName && 
            normalizedInputLastName == normalizedExistingLastName && 
            normalizedExistingFirstName.isNotEmpty && 
            normalizedExistingLastName.isNotEmpty) {
          _showSnackBar(
            "This Name is already registered. Please use a different name.",
            Colors.red.shade700,
            Icons.error_outline,
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
        
        // Check for email duplication
        if (existingEmail.toLowerCase() == email.toLowerCase()) {
          _showSnackBar(
            "This Email Address is already registered. Please use a different email.",
            Colors.red.shade700,
            Icons.error_outline,
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Create user in Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'firstname': firstName, 'lastname': lastName, 'phone': phone, 'role': 'customer'},
      );

      if (authResponse.user != null) {
        // Insert user into users table
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'role': 'customer',
        });

        // Immediately sign in to activate the account
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        debugPrint('=== CUSTOMER CREATED VIA AUTH ===');
        debugPrint('User ID: ${authResponse.user!.id}');
        debugPrint('Email: $email');
        debugPrint('Name: $firstName $lastName');
        debugPrint('SUCCESS: Customer account ready');

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
          errorMessage = 'The Name or Email Address is already registered.';
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
        errorMessage =
            'The Name or Email Address is already registered.';
      } else if (e.message.contains('duplicate')) {
        errorMessage =
            'This email is already registered. Please use a different email.';
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
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                'Syncing with Google...',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isDesktop
          ? AppBar(
              title: const Text('Customer Registration'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
            )
          : null,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Full image background (50%)
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo outside the container
                Image.asset(
                  'assets/images/new-ycplogo.png', // Assuming new-ycplogo.png is the logo shown in the latest image which has transparenc
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/mobile-logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(height: 120),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      // Mobile Registration Form
                      _buildMobileRegistrationForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRegistrationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Name Field
        const Text(
          'First Name',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: firstNameController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your first name',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Last Name Field
        const Text(
          'Last Name',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: lastNameController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your last name',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Phone Number Field
        const Text(
          'Phone Number',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: phoneController,
          enabled: !_isLoading,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: 'Enter your phone number',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Email Field
        const Text(
          'Email Address',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Password Field
        const Text(
          'Password',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Create a password',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Confirm Password Field
        const Text(
          'Confirm Password',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Confirm your password',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE81E0D)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Terms and Conditions Checkbox
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _agreeToTerms,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                activeColor: const Color(0xFFE81E0D),
                checkColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE81E0D)),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'I agree to the Terms and Conditions and Privacy Policy',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Register Button
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE81E0D).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFFEE2A12,
              ), // Vibrant red matching screenshot
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Back to Login Link
        Center(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            child: RichText(
              text: const TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: Color(0xFFE81E0D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Name Field
        Text('First Name', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: firstNameController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your first name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Last Name Field
        Text('Last Name', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: lastNameController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your last name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Phone Number Field
        Text('Phone Number', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: phoneController,
          enabled: !_isLoading,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: 'Enter your phone number',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Email Field
        Text('Email Address', style: Theme.of(context).textTheme.titleSmall),
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
        Text('Password', style: Theme.of(context).textTheme.titleSmall),
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
        Text('Confirm Password', style: Theme.of(context).textTheme.titleSmall),
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
              onChanged: _isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
              activeColor: AppTheme.primaryColor,
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
              backgroundColor: AppTheme.primaryColor,
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

        // Back to Login Link
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            child: Text(
              'Already have an account? Sign In',
              style: TextStyle(
                color: AppTheme.primaryColor,
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
