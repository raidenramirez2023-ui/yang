import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/email_verification_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class CustomerRegistrationPage extends StatefulWidget {
  const CustomerRegistrationPage({super.key});

  @override
  State<CustomerRegistrationPage> createState() =>
      _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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

  // Email verification states
  bool _isEmailVerified = false;
  bool _isVerifyingEmail = false;

  // OTP code input

  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Add listener to password field to trigger confirm password validation
    passwordController.addListener(() {
      if (confirmPasswordController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });

    // Add listener to confirm password field to trigger validation
    confirmPasswordController.addListener(() {
      _formKey.currentState?.validate();
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();
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

  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your First Name';
    }
    if (!_isValidName(value)) {
      return 'Please enter a valid First Name (2-50 chars, letters/spaces/hyphens/apostrophes only)';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Last Name';
    }
    if (!_isValidName(value)) {
      return 'Please enter a valid Last Name (2-50 chars, letters/spaces/hyphens/apostrophes only)';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Phone Number';
    }
    if (value.length != 11 ||
        !value.startsWith('09') ||
        !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Please enter a valid phone number (11 digits, starting with 09)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Email Address';
    }
    final lowercaseEmail = value.toLowerCase();
    if (value != lowercaseEmail ||
        !(value.endsWith('@gmail.com') ||
            value.endsWith('@hotmail.com') ||
            value.endsWith('@outlook.com'))) {
      return 'Please enter a valid Email Address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Password';
    }
    final hasUppercase = value.contains(RegExp(r'[A-Z]'));
    final hasLowercase = value.contains(RegExp(r'[a-z]'));
    final hasDigits = value.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = value.contains(
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
    );

    if (value.length < 8 ||
        !hasUppercase ||
        !hasLowercase ||
        !hasDigits ||
        !hasSpecialCharacters) {
      return 'Password must be at least 8 characters long, contain an uppercase letter, lowercase letter, number, and special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your Password';
    }
    if (passwordController.text.isNotEmpty &&
        value != passwordController.text) {
      return 'Confirm password does not match the password you entered';
    }
    return null;
  }

  String _formatToTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().replaceAllMapped(
      RegExp(r"(^|[\s\-'’])(\p{L}\p{M}*)", unicode: true),
      (Match m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }

  Future<void> handleRegistration() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return; // Form validation will show inline errors
    }

    if (!_agreeToTerms) {
      _showSnackBar(
        "Please agree to the terms and conditions",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    // Check if email is verified
    if (!_isEmailVerified) {
      _showSnackBar(
        "Please verify your email address before registering",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    String rawFirstName = firstNameController.text.trim();
    String rawLastName = lastNameController.text.trim();
    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Formatting names to title case
    String firstName = _formatToTitleCase(rawFirstName);
    String lastName = _formatToTitleCase(rawLastName);

    setState(() => _isLoading = true);

    try {
      // Name duplication validation
      final normalizedInputFirstName = firstName
          .replaceAll(' ', '')
          .toLowerCase();
      final normalizedInputLastName = lastName
          .replaceAll(' ', '')
          .toLowerCase();

      final existingUsers = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname, email, phone');

      for (var user in existingUsers) {
        final existingFirstName = user['firstname']?.toString() ?? '';
        final existingLastName = user['lastname']?.toString() ?? '';
        final existingEmail = user['email']?.toString() ?? '';
        final existingPhone = user['phone']?.toString() ?? '';
        final normalizedExistingFirstName = existingFirstName
            .replaceAll(' ', '')
            .toLowerCase();
        final normalizedExistingLastName = existingLastName
            .replaceAll(' ', '')
            .toLowerCase();

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

        // Check for phone duplication
        if (existingPhone == phone) {
          _showSnackBar(
            "This Phone Number is already registered. Please use a different phone number.",
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
        data: {
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'role': 'customer',
        },
      );

      if (authResponse.user != null) {
        // Insert user into users table with is_approved = true (no admin approval needed)
        await Supabase.instance.client.from('users').insert({
          'id': authResponse.user!.id, // Store Supabase Auth user ID
          'email': email,
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'role': 'customer',
          'is_approved': true, // Auto-approved after email verification
        });

        debugPrint('=== CUSTOMER CREATED VIA AUTH ===');
        debugPrint('User ID: ${authResponse.user!.id}');
        debugPrint('Email: $email');
        debugPrint('Name: $firstName $lastName');
        debugPrint('STATUS: Auto-approved');

        _showSnackBar(
          "Registration successful! You can now login to your account.",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        // Navigate back to login page after successful registration
        if (mounted) {
          Navigator.of(context).pop();
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
        errorMessage = 'The Name or Email Address is already registered.';
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

  // Verify OTP code
  Future<void> _verifyOtpCode() async {
    final otpCode = otpController.text.trim();

    if (otpCode.length != 6) {
      _showSnackBar(
        'Please enter a valid 6-digit code',
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    setState(() {
      _isVerifyingEmail = true;
    });

    try {
      final verificationService = EmailVerificationService();
      final isVerified = await verificationService.verifyEmail(otpCode);

      if (isVerified) {
        setState(() {
          _isEmailVerified = true;
        });

        // Close the modal
        if (mounted) {
          Navigator.of(context).pop();
        }

        _showSnackBar(
          'Email verified successfully!',
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        otpController.clear();
      } else {
        _showSnackBar(
          'Invalid or expired verification code',
          Colors.red.shade700,
          Icons.error_outline,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Error verifying code: $e',
        Colors.red.shade700,
        Icons.error_outline,
      );
    } finally {
      setState(() {
        _isVerifyingEmail = false;
      });
    }
  }

  // Send verification email
  Future<void> _sendVerificationEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar(
        'Please enter your email address first',
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    if (_validateEmail(email) != null) {
      _showSnackBar(
        'Please enter a valid email address',
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    setState(() {
      _isVerifyingEmail = true;
    });

    try {
      // Call the email verification service
      final verificationService = EmailVerificationService();
      final otpCode = await verificationService.sendVerificationEmail(
        email: email,
        appName: 'Yang Chow Restaurant',
      );

      if (otpCode != null) {
        _showSnackBar(
          'Verification code sent! Please check your inbox.',
          Colors.green.shade700,
          Icons.check_circle_outline,
        );
        // Show OTP input modal
        _showOtpInputModal();
      } else {
        throw Exception('Failed to generate verification code');
      }
    } catch (e) {
      _showSnackBar(
        'Failed to send verification code: $e',
        Colors.red.shade700,
        Icons.error_outline,
      );
    } finally {
      setState(() {
        _isVerifyingEmail = false;
      });
    }
  }

  // Show OTP input modal
  void _showOtpInputModal() {
    otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Enter Verification Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter the 6-digit code sent to your email',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isVerifyingEmail ? null : _verifyOtpCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE81E0D),
                      foregroundColor: Colors.white,
                    ),
                    child: _isVerifyingEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTermsAndConditionsModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Terms and Conditions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection(
                  'Personal Information Protection',
                  'We are committed to protecting your privacy. All personal information collected will be used solely for service provision and will never be shared with third parties without your consent.',
                ),
                _buildTermsSection(
                  'User Responsibility',
                  'You are responsible for maintaining the confidentiality of your account credentials. You agree not to share your password and to immediately notify us of any unauthorized access to your account.',
                ),
                _buildTermsSection(
                  'Proper Use of Service',
                  'You agree to use our service only for legitimate purposes. Any misuse, including attempting to access unauthorized areas or disrupting service functionality, is strictly prohibited.',
                ),
                _buildTermsSection(
                  'System Security',
                  'We maintain industry-standard security measures to protect your data. However, no system is completely secure. You acknowledge the inherent risks of online services and absolve us of liability for unauthorized access due to user negligence.',
                ),
                _buildTermsSection(
                  'Policy Updates',
                  'We reserve the right to modify these terms at any time. Continued use of our service following any changes constitutes your acceptance of the new terms.',
                ),
                _buildTermsSection(
                  'Agreement',
                  'By clicking the "Accept" button below, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _agreeToTerms = true;
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
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
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop
          ? _buildDesktopLayout()
          : (isTablet ? _buildTabletLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/YangChow.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: Image.asset(
                  'assets/images/ycplogo.png',
                  width: 450,
                  height: 450,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 40,
                    ),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Form(key: _formKey, child: _buildRegistrationForm()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/YangChow.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/images/ycplogo.png',
                  height: 240,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 0,
                  ),
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Form(key: _formKey, child: _buildRegistrationForm()),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/YangChow.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/ycplogo.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(key: _formKey, child: _buildRegistrationForm()),
                  ),
                  const SizedBox(height: 24),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Indicator
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.grey.shade200, thickness: 1.5),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'CREATE ACCOUNT',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.grey.shade200, thickness: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // First Name Input
        _buildInputField(
          controller: firstNameController,
          hint: 'First Name',
          icon: Icons.person_outline,
          validator: _validateFirstName,
        ),
        const SizedBox(height: 16),

        // Last Name Input
        _buildInputField(
          controller: lastNameController,
          hint: 'Last Name',
          icon: Icons.person_outline,
          validator: _validateLastName,
        ),
        const SizedBox(height: 16),

        // Phone Number Input
        _buildInputField(
          controller: phoneController,
          hint: 'Phone Number (09XXXXXXXXX)',
          icon: Icons.phone_outlined,
          validator: _validatePhone,
          keyboardType: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 16),

        // Email Input with Verify button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: emailController,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading && !_isEmailVerified,
                suffixIcon: _isEmailVerified
                    ? const Icon(Icons.verified, color: Colors.green, size: 20)
                    : null,
              ),
            ),
            if (!_isEmailVerified) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifyingEmail || _isLoading
                      ? null
                      : _sendVerificationEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isVerifyingEmail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
        if (_isEmailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Verified Email Address',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Password Input
        _buildInputField(
          controller: passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          validator: _validatePassword,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey.shade500,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Input
        _buildInputField(
          controller: confirmPasswordController,
          hint: 'Confirm Password',
          icon: Icons.lock_outline,
          validator: _validateConfirmPassword,
          obscureText: !_isConfirmPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey.shade500,
              size: 20,
            ),
            onPressed: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Terms and Conditions
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreeToTerms,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        if (value ?? false) {
                          _showTermsAndConditionsModal();
                        } else {
                          setState(() => _agreeToTerms = false);
                        }
                      },
                activeColor: AppTheme.primaryColor,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I agree to the Terms and Conditions',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Register Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'SIGN UP',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Back to Login Link
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Already have an account?',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled && !_isLoading,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}
