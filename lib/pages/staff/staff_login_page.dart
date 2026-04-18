import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({super.key});

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSessionChecking = true;
  bool _rememberMe = false;

  // Staff roles that can access this portal
  final List<String> _allowedRoles = [
    'admin',
    'inventory staff', 
    'chef',
    'cashier',
    'waitstaff',
    'staff'
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('staff_remember_me') ?? false;
      if (rememberMe) {
        if (mounted) {
          setState(() {
            _rememberMe = true;
            emailController.text = prefs.getString('staff_email') ?? '';
            passwordController.text = prefs.getString('staff_password') ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading staff credentials: $e');
    }
  }

  Future<void> _checkInitialSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null && session.user.email != null) {
      debugPrint('Staff Login: Initial session found for ${session.user.email}');
      
      // Check if user has staff role
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role, firstname, lastname')
          .eq('email', session.user.email!)
          .maybeSingle();

      if (userResponse != null) {
        String userRole = userResponse['role']?.toString().toLowerCase() ?? '';
        String firstName = userResponse['firstname']?.toString() ?? '';
        String lastName = userResponse['lastname']?.toString() ?? '';
        
        // Check if role is allowed for staff portal
        if (_allowedRoles.contains(userRole)) {
          // Create display name - use email if name is empty or "Customer"
          String displayName = firstName.isNotEmpty && firstName != 'Customer' ? firstName : session.user.email!.split('@')[0];
          if (firstName.isEmpty && lastName.isEmpty) {
            displayName = session.user.email!.split('@')[0];
          } else if (firstName.isNotEmpty && lastName.isNotEmpty && firstName != 'Customer') {
            displayName = '$firstName $lastName';
          }
          
          debugPrint('Staff role verified: $userRole');
          debugPrint('Staff display name: "$displayName"');
          
          if (mounted) {
            _showSnackBar("Welcome back, $displayName!", Colors.green.shade700, Icons.check_circle_outline);
            _redirectByUserRole(session.user.email!, userRole);
          }
          return;
        }
      }
      
      // User not authorized for staff portal, sign out
      await Supabase.instance.client.auth.signOut();
    }

    // No valid staff session found, show login form
    if (mounted) {
      setState(() => _isSessionChecking = false);
    }
  }

  void _redirectByUserRole(String email, String userRole) {
    if (!mounted) return;

    if (email.toLowerCase() == 'pagsanjaninv@gmail.com') {
      Navigator.pushReplacementNamed(context, '/pagsanjaninv-dashboard');
    } else if (email.toLowerCase() == 'chefycp@gmail.com' || email.toLowerCase() == 'chefycp.gmail.com') {
      Navigator.pushReplacementNamed(context, '/chef-dashboard');
    } else if (userRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (userRole == 'inventory staff') {
      Navigator.pushReplacementNamed(context, '/pagsanjaninv-dashboard');
    } else if (userRole == 'chef') {
      Navigator.pushReplacementNamed(context, '/chef-dashboard');
    } else if (userRole == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/staff-dashboard');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleStaffLogin() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Please enter email and password",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

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
      // Supabase auth
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Save remember me credentials
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('staff_remember_me', true);
        await prefs.setString('staff_email', email);
        await prefs.setString('staff_password', password);
      } else {
        await prefs.remove('staff_remember_me');
        await prefs.remove('staff_email');
        await prefs.remove('staff_password');
      }

      debugPrint('=== STAFF LOGIN DEBUG ===');
      debugPrint('Email: $email');
      debugPrint('Auth successful');

      // Check if user exists and has staff role
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role, firstname, lastname')
          .eq('email', email)
          .maybeSingle();

      debugPrint('Staff user response: $userResponse');

      if (userResponse == null) {
        _showSnackBar(
          "No staff account found with this email",
          Colors.red.shade700,
          Icons.error_outline,
        );
        await Supabase.instance.client.auth.signOut();
        return;
      }

      String userRole = userResponse['role']?.toString().toLowerCase() ?? '';
      String firstName = userResponse['firstname']?.toString() ?? '';
      String lastName = userResponse['lastname']?.toString() ?? '';

      // Check if role is allowed for staff portal
      if (!_allowedRoles.contains(userRole)) {
        _showSnackBar(
          "This account is not authorized for staff portal access",
          Colors.red.shade700,
          Icons.block,
        );
        await Supabase.instance.client.auth.signOut();
        return;
      }

      debugPrint('Staff role verified: $userRole');
      debugPrint('Staff firstName: "$firstName"');
      debugPrint('Staff lastName: "$lastName"');

      // Create display name - use email if name is empty or "Customer"
      String displayName = firstName.isNotEmpty && firstName != 'Customer' ? firstName : email.split('@')[0];
      if (firstName.isEmpty && lastName.isEmpty) {
        displayName = email.split('@')[0];
      } else if (firstName.isNotEmpty && lastName.isNotEmpty && firstName != 'Customer') {
        displayName = '$firstName $lastName';
      }

      debugPrint('Staff display name: "$displayName"');

      _showSnackBar(
        "Welcome back, $displayName!",
        Colors.green.shade700,
        Icons.check_circle_outline,
      );

      if (mounted) {
        _redirectByUserRole(email, userRole);
      }

    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          errorMessage = 'Invalid email or password';
          break;
        case 'email not confirmed':
          errorMessage = 'Email not confirmed. Please contact administrator.';
          break;
        case 'user not found':
          errorMessage = 'No staff account found with this email';
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
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (_isSessionChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text('Checking staff authentication...', style: TextStyle(color: AppTheme.primaryColor)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Staff themed background
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                  Colors.blue.shade800,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings, size: 120, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(height: 24),
                  Text(
                    'STAFF PORTAL',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yang Chow Restaurant',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Employee Access Only',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Light beige background
        Expanded(
          child: Container(
            color: const Color(0xFFF5F0E8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Staff icon and title
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                        Colors.blue.shade800,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 80, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'STAFF PORTAL',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yang Chow Restaurant',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _buildMobileLoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Login',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to manage shifts and orders.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'STAFF EMAIL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your staff email',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF8B0000), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF8B0000), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Remember Me and Forgot Password Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Remember Me Checkbox
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading
                        ? null
                        : (bool? value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: AppTheme.primaryColor,
                    checkColor: Colors.white,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // Forgot Password Link
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.pushNamed(context, '/forgot-password');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleStaffLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'STAFF LOGIN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Login',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to manage shifts and orders.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          'STAFF EMAIL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your staff email',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF8B0000), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF8B0000), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Remember Me and Forgot Password Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Remember Me Checkbox
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: _isLoading ? null : (value) => setState(() => _rememberMe = value ?? false),
                  activeColor: AppTheme.primaryColor,
                ),
                const Text('Remember me'),
              ],
            ),
            // Forgot Password Link
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.pushNamed(context, '/forgot-password');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleStaffLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                    'STAFF LOGIN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
