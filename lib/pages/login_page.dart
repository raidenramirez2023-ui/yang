import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;
  
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
    'admin2': {
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
      // 🔐 Step 1: Authenticate with Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 📋 Step 2: Get user role from Supabase database
      final userResponse = await _supabase
          .from('users')
          .select('role')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        // Auto-create admin user if not exists (for first-time setup)
        if (email == 'adm.pagsanjan@gmail.com') {
          await _supabase.from('users').insert({
            'email': email,
            'role': 'admin',
          });
          
          _showSnackBar(
            "Admin account created successfully!",
            Colors.green.shade700,
            Icons.check_circle_outline,
          );
          
          // Navigate to admin dashboard
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else {
          _showSnackBar(
            "User not found in database",
            Colors.red.shade700,
            Icons.error_outline,
          );
          await _supabase.auth.signOut();
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // Get the user's role from Supabase
        String userRole = userResponse['role']?.toString().toLowerCase() ?? 'staff';
        
        // 🎉 Step 3: Navigate based on user's role
        _showSnackBar(
          "Login successful as $userRole!",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        if (mounted) {
          // Navigate based on role
          if (userRole == 'admin') {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/staff-dashboard');
          }
        }
      }

    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          errorMessage = 'Invalid email or password';
          break;
        case 'email not confirmed':
          errorMessage = 'Email not confirmed';
          break;
        case 'user not found':
          errorMessage = 'No user found with this email';
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
      backgroundColor: Colors.red.shade600,
      body: Stack(
        children: [
          // Logo Animation (2 seconds mula sa gitna, lumalaki hanggang 500)
          if (!_showLoginPage)
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return SizedBox(
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
                            color: Colors.red.shade600,
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
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mobile-logo.png', // Make sure this path is correct
                    width: 230,
                    height: 230,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // REMOVED: Yang Chow Text
              // const Text(
              //   'Yang Chow',
              //   style: TextStyle(
              //     fontSize: 24,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),
              // const SizedBox(height: 8),
              Text(
                'Restaurant Management System',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color.fromARGB(255, 119, 36, 36),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildLoginForm(),
              const SizedBox(height: 40),
            ],
          ),
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

        // Register Link
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _isLoading ? null : () {
              Navigator.pushNamed(context, '/register');
            },
            child: Text(
              'Create Account',
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