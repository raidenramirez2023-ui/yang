import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String selectedRole = 'Admin'; // default role
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showLoginPage = false;

  late AnimationController _animationController;
  late Animation<double> _logoAnimation;

  // Role definitions with descriptions
  final Map<String, Map<String, String>> roles = {
    'Admin': {
      'icon': 'admin_panel_settings',
      'description': 'Full system access',
      'route': '/dashboard',
    },
    'Staff': {
      'icon': 'point_of_sale',
      'description': 'POS & Transactions',
      'route': '/staff-dashboard',
    },
  };

  @override
  void initState() {
    super.initState();
    
    // Animation controller for 2 seconds
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Logo animation from small to 500
    _logoAnimation = Tween<double>(
      begin: 50.0, // Simula sa maliit
      end: 500.0,  // Hanggang 500
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // Smooth animation
    ));

    // Start animation
    _animationController.forward();

    // Show login page after animation completes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showLoginPage = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Input validation
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Please enter email and password",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    // Email format validation
    if (!email.contains('@')) {
      _showSnackBar(
        "Please enter a valid email address",
        Colors.orange.shade700,
        Icons.warning_amber,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 Step 1: Authenticate with Firebase Auth
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 📋 Step 2: Get user role from Firestore
      QuerySnapshot userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) {
        _showSnackBar(
          "User not found in database",
          Colors.red.shade700,
          Icons.error_outline,
        );
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // Get the user's role from Firestore
      String userRole = userDoc.docs.first.get('role');

      // ✅ Step 3: Verify role matches selection
      if (userRole != selectedRole) {
        _showSnackBar(
          "Invalid role. You are registered as $userRole",
          Colors.red.shade700,
          Icons.error_outline,
        );
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // 🎉 Step 4: Navigate based on verified role
      _showSnackBar(
        "Login successful as $userRole",
        Colors.green.shade700,
        Icons.check_circle_outline,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        final roleData = roles[userRole];
        if (roleData != null) {
          Navigator.pushReplacementNamed(context, roleData['route']!);
        }
      });

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _showSnackBar(errorMessage, Colors.red.shade700, Icons.error_outline);
    } catch (e) {
      _showSnackBar(
        "An error occurred: $e",
        Colors.red.shade700,
        Icons.error_outline,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
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
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(254, 0, 2, 1),
      body: Stack(
        children: [
          // Logo Animation (2 seconds mula sa gitna, lumalaki hanggang 500)
          if (!_showLoginPage)
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: _logoAnimation.value,
                    height: _logoAnimation.value,
                    child: Image.asset(
                      'assets/images/ycplogo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: _logoAnimation.value,
                          height: _logoAnimation.value,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: const Color.fromRGBO(254, 0, 2, 1),
                            size: _logoAnimation.value * 0.5,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

          // Login Page (lalabas pagkatapos ng 2 seconds) - 50-50 background
          if (_showLoginPage)
            (isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Red background (50%)
        Expanded(
          child: Container(
            color: const Color.fromRGBO(254, 0, 2, 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            color: AppTheme.white,
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Yang Chow',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Restaurant Management System',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.white.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Secure Login Portal',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right side - White background (50%)
        Expanded(
          child: Container(
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu,
                color: AppTheme.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Yang Chow',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Restaurant Management System',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.mediumGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildLoginForm(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Field
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 20),

        // Password Field
        Text(
          'Password',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your password',
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
        const SizedBox(height: 20),

        // Role Selection
        Text(
          'Login As',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.lightGrey),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              elevation: 2,
              style: Theme.of(context).textTheme.bodyLarge,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: AppTheme.md,
              ),
              items: ['Admin', 'Staff'].map((role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == 'Admin' 
                          ? Icons.admin_panel_settings 
                          : Icons.point_of_sale,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(role),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) {
                if (value != null) {
                  setState(() {
                    selectedRole = value;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleLogin,
            child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                  ),
                )
              : const Text('Sign In'),
          ),
        ),
        const SizedBox(height: 8),

        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : () {
              Navigator.pushNamed(context, '/forgot-password');
            },
            child: Text(
              'Forgot Password?',
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