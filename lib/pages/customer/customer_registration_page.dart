import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _agreeToPrivacy = false;
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

    if (!_agreeToPrivacy) {
      _showSnackBar(
        "Please agree to the Privacy Policy",
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
                      backgroundColor: Colors.red.shade700,
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

  void _showPrivacyPolicyModal() {
    const boldStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: Colors.black87,
      height: 1.5,
    );
    const normalStyle = TextStyle(
      fontSize: 13,
      color: Colors.black54,
      height: 1.5,
    );
    const sectionTitleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: Colors.black87,
    );
    const subSectionTitleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13.5,
      color: Colors.black87,
    );

    Widget buildBullet(List<TextSpan> spans) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: normalStyle),
            Expanded(child: RichText(text: TextSpan(children: spans))),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Privacy Policy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro paragraph
                  Text(
                    'Last updated: August 25, 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yang Chow Restaurant ("we", "our", or "us") operates the Yang Chow mobile application (the "App"). '
                    'This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our App.',
                    style: normalStyle,
                  ),

                  // ── 1. Information We Collect ──
                  const SizedBox(height: 20),
                  const Text('1. Information We Collect', style: sectionTitleStyle),
                  const SizedBox(height: 12),

                  // 1.1 Personal Information
                  const Text('1.1 Personal Information', style: subSectionTitleStyle),
                  const SizedBox(height: 8),
                  buildBullet([
                    const TextSpan(text: 'Contact Information: ', style: boldStyle),
                    const TextSpan(text: 'Firstname, Lastname, Phone Number, Valid ID, and Valid Email Address (if you voluntarily provide it).', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Account Information: ', style: boldStyle),
                    const TextSpan(text: 'username, password, and any profile details you choose to share.', style: normalStyle),
                  ]),

                  // 1.2 Non-Personal Information
                  const SizedBox(height: 12),
                  const Text('1.2 Non-Personal Information', style: subSectionTitleStyle),
                  const SizedBox(height: 8),
                  buildBullet([
                    const TextSpan(text: 'Device Information: ', style: boldStyle),
                    const TextSpan(text: 'device model, operating system version, unique device identifiers, and IP address.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Usage Data: ', style: boldStyle),
                    const TextSpan(text: 'interaction logs, crash reports, analytics events, and performance data.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Location Data: ', style: boldStyle),
                    const TextSpan(text: 'approximate location derived from IP address or device GPS (only if you enable location services).', style: normalStyle),
                  ]),

                  // ── 2. How We Use Your Information ──
                  const SizedBox(height: 20),
                  const Text('2. How We Use Your Information', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  buildBullet([
                    const TextSpan(text: 'Provide & Maintain the Service: ', style: boldStyle),
                    const TextSpan(text: 'to operate, personalize, and improve the App.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Communication: ', style: boldStyle),
                    const TextSpan(text: 'to send you updates, security alerts, support messages, and marketing communications (you may opt-out).', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Analytics & Research: ', style: boldStyle),
                    const TextSpan(text: 'to analyze usage patterns, diagnose technical issues, and develop new features.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Legal Compliance: ', style: boldStyle),
                    const TextSpan(text: 'to comply with legal obligations, enforce our Terms of Service, and protect against fraud.', style: normalStyle),
                  ]),

                  // ── 3. Sharing & Disclosure ──
                  const SizedBox(height: 20),
                  const Text('3. Sharing & Disclosure', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text('We may share your information with:', style: normalStyle),
                  const SizedBox(height: 4),
                  buildBullet([
                    const TextSpan(text: 'Service Providers: ', style: boldStyle),
                    const TextSpan(text: 'third-party vendors that help us host, analyze, or support the App (e.g., cloud providers, analytics services). They are contractually obligated to protect your data.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Legal Requirements: ', style: boldStyle),
                    const TextSpan(text: 'when required by law, subpoena, or governmental request.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Business Transfers: ', style: boldStyle),
                    const TextSpan(text: 'in connection with a merger, acquisition, or sale of assets, provided the acquiring entity agrees to honor this Privacy Policy.', style: normalStyle),
                  ]),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'We ', style: normalStyle),
                        TextSpan(text: 'do not sell', style: boldStyle),
                        TextSpan(text: ' your personal information to third parties.', style: normalStyle),
                      ],
                    ),
                  ),

                  // ── 4. Data Retention ──
                  const SizedBox(height: 20),
                  const Text('4. Data Retention', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'We retain your personal data only for as long as necessary to fulfill the purposes outlined in this Privacy Policy, '
                    'unless a longer retention period is required or permitted by law.',
                    style: normalStyle,
                  ),

                  // ── 5. Your Rights & Choices ──
                  const SizedBox(height: 20),
                  const Text('5. Your Rights & Choices', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  buildBullet([
                    const TextSpan(text: 'Access & Correction: ', style: boldStyle),
                    const TextSpan(text: 'you may request access to, correction of, or deletion of your personal data.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Opt-Out: ', style: boldStyle),
                    const TextSpan(text: 'you can opt out of marketing communications via the unsubscribe link in our emails or by adjusting app settings.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Location Services: ', style: boldStyle),
                    const TextSpan(text: 'you can disable location permissions in your device settings.', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Data Portability: ', style: boldStyle),
                    const TextSpan(text: 'upon request, we can provide a copy of your personal data in a machine-readable format.', style: normalStyle),
                  ]),

                  // ── 6. Security ──
                  const SizedBox(height: 20),
                  const Text('6. Security', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'We implement reasonable technical and organizational measures to protect your data against unauthorized access, alteration, '
                    'disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
                    style: normalStyle,
                  ),

                  // ── 7. Children's Privacy ──
                  const SizedBox(height: 20),
                  const Text("7. Children's Privacy", style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'The App is not directed at children under the age of 18, and we do not knowingly collect personal information from minors. '
                    'Users must be 18 years of age or older to use this App.',
                    style: normalStyle,
                  ),

                  // ── 8. International Transfers ──
                  const SizedBox(height: 20),
                  const Text('8. International Transfers', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'Your information may be transferred to, and processed in, countries outside your residence, which may have different data protection laws. '
                    'We will ensure appropriate safeguards are in place.',
                    style: normalStyle,
                  ),

                  // ── 9. Changes to This Privacy Policy ──
                  const SizedBox(height: 20),
                  const Text('9. Changes to This Privacy Policy', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy '
                    'within the App and updating the "Last updated" date.',
                    style: normalStyle,
                  ),

                  // ── 10. Contact Us ──
                  const SizedBox(height: 20),
                  const Text('10. Contact Us', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  const Text(
                    'If you have any questions about this Privacy Policy, please contact us at:',
                    style: normalStyle,
                  ),
                  const SizedBox(height: 4),
                  buildBullet([
                    const TextSpan(text: 'Email: ', style: boldStyle),
                    const TextSpan(text: 'bsit-ycprms@yc-pagsanjan.site', style: normalStyle),
                  ]),
                  buildBullet([
                    const TextSpan(text: 'Address: ', style: boldStyle),
                    const TextSpan(text: 'CLA TOWN CENTER MALL, Ground floor near at mall entrance.', style: normalStyle),
                  ]),
                ],
              ),
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
                  _agreeToPrivacy = true;
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

  // ─── Yang Chow Luxury Emerald Green & Gold Theme Palette ───────────
  static const Color _forestGreen = Color(0xFF14332E); // Deep Emerald
  static const Color _activeEmerald = Color(0xFF1E4D40); // Active Emerald
  static const Color _warmGold = Color(0xFFD9A441); // Muted Gold Accent
  static const Color _primaryGold = Color(0xFFC9922E); // Primary Gold Accent
  static const Color _darkForest = Color(0xFF0D231F); // Dark Forest
  static const Color _deepBurgundy = Color(0xFF071512); // Deep Jade Shadow

  @override
  Widget build(BuildContext context) {
    if (_isRedirecting) {
      return Scaffold(
        backgroundColor: _deepBurgundy,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
                  border: Border.all(color: _warmGold.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _warmGold.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: _warmGold,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Syncing with Google...',
                style: GoogleFonts.poppins(
                  color: _warmGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: _deepBurgundy,
      body: isDesktop
          ? _buildDesktopLayout()
          : (isTablet ? _buildTabletLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/YangChow.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _deepBurgundy.withOpacity(0.94),
                    _darkForest.withOpacity(0.90),
                    _forestGreen.withOpacity(0.86),
                    const Color(0xFF04120E).withOpacity(0.96),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryGold.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _warmGold.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _warmGold),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFFFAEB),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        _buildBackground(),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                // Left Brand Showcase
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.25),
                              border: Border.all(
                                color: _warmGold.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _warmGold.withOpacity(0.25),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/ycplogo.png',
                              width: 220,
                              height: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'YANG CHOW',
                            style: GoogleFonts.cinzel(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: _warmGold,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AUTHENTIC CHINESE RESTAURANT',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFE8B2),
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primaryGold.withOpacity(0.3),
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _buildFeatureBadge(Icons.restaurant, 'Chinese Specialties'),
                                _buildFeatureBadge(Icons.alarm_on, 'Advance Ordering'),
                                _buildFeatureBadge(Icons.celebration, 'Event Reservation'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right Registration Form Card
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        margin: const EdgeInsets.only(right: 36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _primaryGold.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: _primaryGold.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_primaryGold, _warmGold, _forestGreen],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 36,
                                  vertical: 32,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: _buildRegistrationForm(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Stack(
      children: [
        _buildBackground(),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.25),
                    border: Border.all(
                      color: _warmGold.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _warmGold.withOpacity(0.2),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/ycplogo.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'YANG CHOW',
                  style: GoogleFonts.cinzel(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _warmGold,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _primaryGold.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: _primaryGold.withOpacity(0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 5,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primaryGold, _warmGold, _forestGreen],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: _buildRegistrationForm(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
        _buildBackground(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallPhone = screenWidth < 380;
              final logoSize = isSmallPhone ? 70.0 : 80.0;

              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallPhone ? 12 : 20,
                    vertical: isSmallPhone ? 18 : 28,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallPhone ? 10 : 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.25),
                          border: Border.all(
                            color: _warmGold.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _warmGold.withOpacity(0.2),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/ycplogo.png',
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'YANG CHOW',
                        style: GoogleFonts.cinzel(
                          fontSize: isSmallPhone ? 20 : 22,
                          fontWeight: FontWeight.w800,
                          color: _warmGold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _primaryGold.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: _primaryGold.withOpacity(0.12),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 4,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_primaryGold, _warmGold, _forestGreen],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallPhone ? 16 : 22,
                                  vertical: isSmallPhone ? 20 : 26,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: _buildRegistrationForm(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
        // Role Indicator Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _forestGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _primaryGold.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_alt_1, size: 14, color: _forestGreen),
                const SizedBox(width: 6),
                Text(
                  'CREATE ACCOUNT',
                  style: GoogleFonts.poppins(
                    color: _forestGreen,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Welcome Header
        Text(
          'Join Yang Chow',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F2B24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create an account to start ordering & reserving',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),

        // First Name Input
        _buildInputField(
          controller: firstNameController,
          hint: 'First Name',
          icon: Icons.person_outline,
          validator: _validateFirstName,
        ),
        const SizedBox(height: 14),

        // Last Name Input
        _buildInputField(
          controller: lastNameController,
          hint: 'Last Name',
          icon: Icons.person_outline,
          validator: _validateLastName,
        ),
        const SizedBox(height: 14),

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
        const SizedBox(height: 14),

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
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifyingEmail || _isLoading
                      ? null
                      : _sendVerificationEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _forestGreen,
                    foregroundColor: const Color(0xFFFFFAEB),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                    side: BorderSide(color: _warmGold.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isVerifyingEmail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _warmGold,
                            ),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
        if (_isEmailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Verified Email Address',
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

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
              color: Colors.grey.shade600,
              size: 19,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 14),

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
              color: Colors.grey.shade600,
              size: 19,
            ),
            onPressed: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Terms and Conditions
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
                        if (value ?? false) {
                          _showTermsAndConditionsModal();
                        } else {
                          setState(() => _agreeToTerms = false);
                        }
                      },
                activeColor: _forestGreen,
                checkColor: _warmGold,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showTermsAndConditionsModal,
                child: Text(
                  'I agree to the Terms and Conditions',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Privacy Policy Checkbox
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _agreeToPrivacy,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        if (value ?? false) {
                          _showPrivacyPolicyModal();
                        } else {
                          setState(() => _agreeToPrivacy = false);
                        }
                      },
                activeColor: _forestGreen,
                checkColor: _warmGold,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showPrivacyPolicyModal,
                child: Text(
                  'I agree to the Privacy Policy',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Register Button with Emerald & Gold Theme
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                _forestGreen,
                _activeEmerald,
                _darkForest,
              ],
            ),
            border: Border.all(
              color: _warmGold.withOpacity(0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _forestGreen.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : handleRegistration,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(_warmGold),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIGN UP',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: const Color(0xFFFFFAEB),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: _warmGold,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Back to Login Link
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
            GestureDetector(
              onTap: _isLoading ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Log In',
                style: GoogleFonts.poppins(
                  color: _forestGreen,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _forestGreen,
                ),
              ),
            ),
          ],
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
      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: _primaryGold, size: 19),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFCFAF7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _primaryGold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Colors.red, width: 1.8),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
