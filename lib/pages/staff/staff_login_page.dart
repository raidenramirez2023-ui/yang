import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/global_messenger.dart';

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
            GlobalMessenger.showSuccess("Welcome back, $displayName!");
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
      GlobalMessenger.showError("Please enter email and password");
      return;
    }

    if (!email.contains('@')) {
      GlobalMessenger.showWarning("Please enter a valid email address");
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
        GlobalMessenger.showError("No staff account found with this email");
        await Supabase.instance.client.auth.signOut();
        return;
      }

      String userRole = userResponse['role']?.toString().toLowerCase() ?? '';
      String firstName = userResponse['firstname']?.toString() ?? '';
      String lastName = userResponse['lastname']?.toString() ?? '';

      // Check if role is allowed for staff portal
      if (!_allowedRoles.contains(userRole)) {
        GlobalMessenger.showError("This account is not authorized for staff portal access");
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

      if (mounted) {
        GlobalMessenger.showSuccess("Welcome back, $displayName!");
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
      GlobalMessenger.showError(errorMessage);
    } catch (e) {
      GlobalMessenger.showError("An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Yang Chow Standard Red & Gold Theme Palette ───────────────────
  static const Color _forestGreen = Color(0xFF990000); // dark red
  static const Color _activeEmerald = Color(0xFFAA0000); // medium red
  static const Color _warmGold = Color(0xFFFFD166); // warm gold accent
  static const Color _primaryGold = Color(0xFFC9922E); // amber gold
  static const Color _darkForest = Color(0xFF770000); // darkest red
  static const Color _deepBurgundy = Color(0xFF380202); // deep wine burgundy

  @override
  Widget build(BuildContext context) {
    if (_isSessionChecking) {
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
                'Checking staff authentication...',
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
                    const Color(0xFF220000).withOpacity(0.96),
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
                  flex: 6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
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
                              width: 240,
                              height: 240,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'YANG CHOW',
                            style: GoogleFonts.cinzel(
                              fontSize: 34,
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
                          const SizedBox(height: 8),
                          Text(
                            'STAFF & OPERATIONS PORTAL',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFE8B2),
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
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
                                _buildFeatureBadge(Icons.soup_kitchen, 'Kitchen & Orders'),
                                _buildFeatureBadge(Icons.inventory_2_outlined, 'Inventory Control'),
                                _buildFeatureBadge(Icons.point_of_sale, 'POS & Cashier'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right Login Form Card
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        margin: const EdgeInsets.only(right: 48),
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
                                  horizontal: 40,
                                  vertical: 38,
                                ),
                                child: _buildLoginForm(),
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
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
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
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'YANG CHOW',
                  style: GoogleFonts.cinzel(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _warmGold,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 460),
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
                          padding: const EdgeInsets.all(36),
                          child: _buildLoginForm(),
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
              final logoSize = isSmallPhone ? 70.0 : 85.0;

              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallPhone ? 12 : 20,
                    vertical: isSmallPhone ? 20 : 28,
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
                        constraints: const BoxConstraints(maxWidth: 420),
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
                                  horizontal: isSmallPhone ? 16 : 24,
                                  vertical: isSmallPhone ? 22 : 28,
                                ),
                                child: _buildLoginForm(),
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

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Indicator Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                const Icon(Icons.admin_panel_settings_outlined, size: 15, color: _forestGreen),
                const SizedBox(width: 6),
                Text(
                  'STAFF PORTAL',
                  style: GoogleFonts.poppins(
                    color: _forestGreen,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Welcome Header
        Text(
          'Staff Login',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF330505),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Authorized staff & operational access only',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 26),

        // Email Input
        Text(
          'Staff Email',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3D2A1D),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.black87),
            onSubmitted: (_) => _isLoading ? null : handleStaffLogin(),
            decoration: InputDecoration(
              hintText: 'e.g. staff@yangchow.com',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFCFAF7),
              prefixIcon: const Icon(
                Icons.badge_outlined,
                color: _primaryGold,
                size: 19,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Password Input
        Text(
          'Password',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3D2A1D),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: passwordController,
            obscureText: !_isPasswordVisible,
            enabled: !_isLoading,
            style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.black87),
            onSubmitted: (_) => _isLoading ? null : handleStaffLogin(),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFCFAF7),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: _primaryGold,
                size: 19,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade600,
                  size: 19,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Remember Me and Forgot Password Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                    activeColor: _forestGreen,
                    checkColor: _warmGold,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Remember me',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/forgot-password'),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sign In Button
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                _forestGreen,
                Color(0xFFBA1717),
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
              onTap: _isLoading ? null : handleStaffLogin,
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
                            'SIGN IN',
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
      ],
    );
  }
}
