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
    'staff',
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
      debugPrint(
        'Staff Login: Initial session found for ${session.user.email}',
      );

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
          String displayName = firstName.isNotEmpty && firstName != 'Customer'
              ? firstName
              : session.user.email!.split('@')[0];
          if (firstName.isEmpty && lastName.isEmpty) {
            displayName = session.user.email!.split('@')[0];
          } else if (firstName.isNotEmpty &&
              lastName.isNotEmpty &&
              firstName != 'Customer') {
            displayName = '$firstName $lastName';
          }

          debugPrint('Staff role verified: $userRole');
          debugPrint('Staff display name: "$displayName"');

          if (mounted) {
            _showSnackBar(
              "Welcome back, $displayName!",
              Colors.green.shade700,
              Icons.check_circle_outline,
            );
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
    } else if (email.toLowerCase() == 'chefycp@gmail.com' ||
        email.toLowerCase() == 'chefycp.gmail.com') {
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
      String displayName = firstName.isNotEmpty && firstName != 'Customer'
          ? firstName
          : email.split('@')[0];
      if (firstName.isEmpty && lastName.isEmpty) {
        displayName = email.split('@')[0];
      } else if (firstName.isNotEmpty &&
          lastName.isNotEmpty &&
          firstName != 'Customer') {
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
    if (_isSessionChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                'Checking staff authentication...',
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/ycplogo.png',
                      width: 450,
                      height: 450,
                      fit: BoxFit.contain,
                    ),
                  ],
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
                    child: _buildLoginForm(),
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
                  child: _buildLoginForm(),
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
                    child: _buildLoginForm(),
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

  Widget _buildLoginForm() {
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
                'STAFF LOGIN',
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

        // Email Input
        const Text(
          'STAFF EMAIL',
          style: TextStyle(
            fontSize: 11,
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter Staff Email',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Colors.grey.shade500,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white,
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
          ),
        ),
        const SizedBox(height: 20),

        // Password Input
        const Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 11,
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter Password',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.grey.shade500,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey.shade500,
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
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
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
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading
                        ? null
                        : (bool? value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                    activeColor: AppTheme.primaryColor,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Remember me',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Forgot Password Link
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Login Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleStaffLogin,
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
                    'SIGN IN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
