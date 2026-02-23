import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

      // 🎉 Step 3: Navigate based on user's role from Firestore
      _showSnackBar(
        "Login successful as $userRole",
        Colors.green.shade700,
        Icons.check_circle_outline,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final roleData = roles[userRole];
          if (roleData != null) {
            Navigator.pushReplacementNamed(context, roleData['route']!);
          }
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

  Future<void> handleGoogleSignIn() async {
  setState(() => _isLoading = true);

  try {
    // For google_sign_in 7.2.0 - Web implementation
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: '907696484085-l011o1bekvcfthf9iil3of88cjsg5vd9.apps.googleusercontent.com', // Add this line
    );
    
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      // User canceled sign in
      setState(() => _isLoading = false);
      return;
    }

    // Get authentication details from the request
    final GoogleSignInAuthentication googleAuth = 
        await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the credential
    final UserCredential userCredential = 
        await _auth.signInWithCredential(credential);
    
    final User? user = userCredential.user;
    
    if (user != null) {
      // Check if user exists in Firestore
      QuerySnapshot userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      String userRole;
      
      if (userDoc.docs.isEmpty) {
        // New user - create record with default role
        userRole = 'Staff'; // Default role for new Google users
        
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName,
          'role': userRole,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Existing user - get role from Firestore
        userRole = userDoc.docs.first.get('role');
        
        // Update last login
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      // Show success message
      _showSnackBar(
        "Google Sign-In successful as $userRole",
        Colors.green.shade700,
        Icons.check_circle_outline,
      );

      // Navigate based on role
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final roleData = roles[userRole];
          if (roleData != null) {
            Navigator.pushReplacementNamed(context, roleData['route']!);
          } else {
            Navigator.pushReplacementNamed(context, '/staff-dashboard');
          }
        }
      });
    }

  } on FirebaseAuthException catch (e) {
    String errorMessage;
    switch (e.code) {
      case 'account-exists-with-different-credential':
        errorMessage = 'Account exists with different credentials';
        break;
      case 'invalid-credential':
        errorMessage = 'Invalid credential';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Google Sign-In is not enabled';
        break;
      case 'user-disabled':
        errorMessage = 'This account has been disabled';
        break;
      case 'popup-closed-by-user':
        errorMessage = 'Sign-in cancelled';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Check your connection';
        break;
      default:
        errorMessage = 'Google Sign-In failed: ${e.message}';
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
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: Colors.red.shade600,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Yang Chow',
                style: TextStyle(
                  fontSize: 24,
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
        Center(child: Text('or', style: Theme.of(context).textTheme.titleSmall)),
        const SizedBox(height: 8),
      // Connect with Google Button
        SizedBox(
          width: double.infinity,
          height: 30,
          child: OutlinedButton(
            onPressed: _isLoading ? null : handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/glogo.png',
                  height: 24,
                  width: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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