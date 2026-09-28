import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/global_messenger.dart';
import '../../services/app_settings_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/admin_continuity_service.dart';

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
    'developer',
    'admin',
    'backup_admin',
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
          .ilike('email', session.user.email!)
          .maybeSingle();

      if (userResponse != null) {
        final email = session.user.email!.trim().toLowerCase();

        // Security Check: Verify account has not been deactivated via emergency succession
        final isDeactivated = await AdminContinuityService.isAccountDeactivated(email);
        if (isDeactivated) {
          debugPrint('Deactivated administrator account detected in initial session: $email');
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            setState(() => _isSessionChecking = false);
            GlobalMessenger.showError("This administrative account has been deactivated following an Administrative Succession. Access denied.");
          }
          return;
        }

        String userRole = userResponse['role']?.toString().toLowerCase() ?? '';
        String firstName = userResponse['firstname']?.toString() ?? '';
        String lastName = userResponse['lastname']?.toString() ?? '';

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

        // Security Check 2: Verify Backup Admin is not locked in Standby mode
        final isStandbyLocked = await AdminContinuityService.isBackupAdminLockedInStandby(session.user.email!);
        if (isStandbyLocked) {
          debugPrint('Standby backup admin detected in initial session: ${session.user.email}');
          if (mounted) {
            setState(() => _isSessionChecking = false);
            _showStandbyLockDialog(session.user.email!, displayName: displayName);
          }
          return;
        }

        // Check if role is allowed for staff portal
        if (_allowedRoles.contains(userRole)) {
          debugPrint('Staff role verified: $userRole');
          debugPrint('Staff display name: "$displayName"');

          if (mounted) {
            await _redirectByUserRole(session.user.email!, userRole, displayName);
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

  Future<void> _redirectByUserRole(String email, String userRole, [String displayName = '']) async {
    if (!mounted) return;

    // Check Maintenance Mode — always fetch fresh from DB, not from stale cache.
    // Block roles EXCEPT developer and admin (admin has restricted access during maintenance).
    if (userRole != 'developer' && userRole != 'admin') {
      try {
        final isMaintenance = await AppSettingsService.checkMaintenanceModeFromDB();
        if (isMaintenance) {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/maintenance',
              arguments: {'returnRoute': '/staff-login'},
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Could not verify maintenance mode: $e');
        // Fall back to cached value as safety net
        if (AppSettingsService().isMaintenanceModeEnabled()) {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/maintenance',
              arguments: {'returnRoute': '/staff-login'},
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;

    // Audit log privileged login for security tracking
    if (userRole != 'customer') {
      try {
        AuditLogService.logActivity(
          action: 'LOGIN',
          module: 'Auth',
          description: 'Staff logged in ($userRole): $email',
          customUserEmail: email,
          customUserName: displayName.isNotEmpty ? displayName : email.split('@').first,
          customUserRole: userRole.toUpperCase(),
          metadata: {
            'role': userRole,
            'portal': 'staff_portal',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (_) {}
    }

    // Only show welcome message if not blocked by maintenance
    if (displayName.isNotEmpty) {
      GlobalMessenger.showSuccess("Welcome back, $displayName!");
    }

    if (email.toLowerCase() == 'pagsanjaninv@gmail.com' ||
        email.toLowerCase() == 'pagsanjaninv.gmail.com') {
      Navigator.pushReplacementNamed(context, '/inventory/dashboard');
    } else if (email.toLowerCase() == 'chefycp@gmail.com' ||
        email.toLowerCase() == 'chefycp.gmail.com') {
      Navigator.pushReplacementNamed(context, '/chef/dashboard');
    } else if (userRole == 'developer') {
      Navigator.pushReplacementNamed(context, '/developer/dashboard');
    } else if (userRole == 'admin' || userRole == 'backup_admin') {
      Navigator.pushReplacementNamed(context, '/admin/dashboard');
    } else if (userRole == 'inventory staff' || userRole == 'pagsanjaninv') {
      Navigator.pushReplacementNamed(context, '/inventory/dashboard');
    } else if (userRole == 'chef') {
      Navigator.pushReplacementNamed(context, '/chef/dashboard');
    } else if (userRole == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/staff/dashboard');
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
          .ilike('email', email)
          .maybeSingle();

      // If emergency succession was executed locally, sync it to cloud Supabase now that user is authenticated
      try {
        final cfg = await AdminContinuityService.getConfig();
        final prefs = await SharedPreferences.getInstance();
        if (cfg.isSuccessionCompleted &&
            prefs.getBool('yang_emergency_succession_completed') == true &&
            prefs.getString('yang_active_primary_admin_email') == email.toLowerCase()) {
          final formerEmail = prefs.getString('yang_former_deactivated_admin_email') ??
              (cfg.formerAdminEmail != null && cfg.formerAdminEmail!.isNotEmpty
                  ? cfg.formerAdminEmail!
                  : 'admn.pagsanjan@gmail.com');
          final updatedCloud = AdminContinuityConfig(
            primaryAdminEmail: email,
            primaryAdminName: userResponse != null
                ? '${userResponse['firstname'] ?? ''} ${userResponse['lastname'] ?? ''}'.trim()
                : 'Primary Administrator',
            primaryAdminPhone: cfg.backupAdminPhone,
            primaryAdminTitle: 'Primary System Administrator',
            backupAdminEmail: '',
            backupAdminName: '',
            backupAdminPhone: '',
            backupAdminTitle: 'Authorized Backup Administrator',
            status: 'succession_completed',
            formerAdminEmail: formerEmail,
            formerAdminName: cfg.formerAdminName ?? 'Tony Stark',
            securityVerificationKey: cfg.securityVerificationKey,
            lastUpdated: DateTime.now(),
          );
          await AdminContinuityService.saveConfig(updatedCloud);
          try {
            await Supabase.instance.client.from('users').update({
              'role': 'admin',
            }).ilike('email', email);
          } catch (_) {}
        } else if (!cfg.isSuccessionCompleted) {
          // Clean up stale local flags if cloud config is in normal active state
          await prefs.remove('yang_emergency_succession_completed');
          await prefs.remove('yang_former_deactivated_admin_email');
          await prefs.remove('yang_active_primary_admin_email');
        }
      } catch (_) {}

      debugPrint('Staff user response: $userResponse');

      if (userResponse == null) {
        GlobalMessenger.showError("No staff account found with this email");
        await Supabase.instance.client.auth.signOut();
        return;
      }

      // Security Check: Verify account has not been deactivated via emergency succession
      final isDeactivated = await AdminContinuityService.isAccountDeactivated(email);
      if (isDeactivated) {
        debugPrint('Blocked login attempt for deactivated admin: $email');
        GlobalMessenger.showError("This administrative account has been deactivated following an Administrative Succession. Access denied.");
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

      // Security Check 2: Verify Backup Admin is not locked in Standby mode
      final isStandbyLocked = await AdminContinuityService.isBackupAdminLockedInStandby(email);
      if (isStandbyLocked) {
        if (mounted) {
          _showStandbyLockDialog(email, displayName: displayName);
        }
        return;
      }

      if (mounted) {
        await _redirectByUserRole(email, userRole, displayName);
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
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border.all(color: _warmGold.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _warmGold.withValues(alpha: 0.2),
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
                    _deepBurgundy.withValues(alpha: 0.94),
                    _darkForest.withValues(alpha: 0.90),
                    _forestGreen.withValues(alpha: 0.86),
                    const Color(0xFF220000).withValues(alpha: 0.96),
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
                    _primaryGold.withValues(alpha: 0.25),
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
                    _warmGold.withValues(alpha: 0.18),
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
                              color: Colors.black.withValues(alpha: 0.25),
                              border: Border.all(
                                color: _warmGold.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _warmGold.withValues(alpha: 0.25),
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
                                  color: Colors.black.withValues(alpha: 0.6),
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
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primaryGold.withValues(alpha: 0.3),
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
                            color: _primaryGold.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: _primaryGold.withValues(alpha: 0.15),
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
                    color: Colors.black.withValues(alpha: 0.25),
                    border: Border.all(
                      color: _warmGold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _warmGold.withValues(alpha: 0.2),
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
                      color: _primaryGold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: _primaryGold.withValues(alpha: 0.15),
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
                          color: Colors.black.withValues(alpha: 0.25),
                          border: Border.all(
                            color: _warmGold.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _warmGold.withValues(alpha: 0.2),
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
                            color: _primaryGold.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: _primaryGold.withValues(alpha: 0.12),
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
              color: _forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _primaryGold.withValues(alpha: 0.5),
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
              color: _warmGold.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _forestGreen.withValues(alpha: 0.4),
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
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _isLoading ? null : _handleDirectEmergencySuccessionTap,
            icon: const Icon(Icons.shield_outlined, size: 14, color: _warmGold),
            label: Text(
              'Backup Admin? Emergency Succession Protocol',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: _warmGold.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: _warmGold.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleDirectEmergencySuccessionTap() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      GlobalMessenger.showInfo(
        'Please enter your Backup Administrator Email and Password above to verify identity.',
      );
      return;
    }

    // Authenticate and launch
    handleStaffLogin();
  }

  void _showStandbyLockDialog(String email, {String displayName = ''}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0B0B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _warmGold.withValues(alpha: 0.6), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrative Standby Notice',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFFFFFAEB),
                    ),
                  ),
                  Text(
                    'Business Continuity & Access Control',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'STANDBY MODE — LOGIN LOCKED',
                  style: GoogleFonts.inter(
                    color: _warmGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE2E8F0),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Account '),
                    TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const TextSpan(
                      text: ' is designated as an ',
                    ),
                    const TextSpan(
                      text: 'Authorized Backup Administrator',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber),
                    ),
                    const TextSpan(
                      text: ' in Standby Mode.\n\nPer restaurant enterprise security protocols (NIST SP 800-63 / ISO 27001):',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1414),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryGold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_clock_outlined, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Normal Staff Login is locked while the Primary Administrator is active.',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'For daily Co-Admin access, request the Primary Administrator to authorize this account inside the Admin Continuity dashboard.',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If the Primary Administrator is permanently unavailable (e.g. accident or death), tap "Initiate Emergency Succession" below with the authorized Security Key.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFECACA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            child: Text(
              'Understood & Exit',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEmergencySuccessionDialog(email, displayName: displayName);
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text(
              'Initiate Emergency Succession',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencySuccessionDialog(String email, {String displayName = ''}) async {
    final config = await AdminContinuityService.getConfig();
    if (!mounted) return;

    final reasonController = TextEditingController(text: 'Permanent Medical Incapacitation / Deceased');
    final referenceController = TextEditingController();
    final keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureKey = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E0B0B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Succession Protocol',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFFFFFAEB),
                      ),
                    ),
                    Text(
                      'Business Continuity & Disaster Takeover',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 490,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF991B1B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFFFCA5A5), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AUTHORITY TRANSFER NOTICE',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFCA5A5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You are initiating formal Administrative Succession for Yang Chow Palace.\n\n'
                            '• Successor Account: $email (${displayName.isNotEmpty ? displayName : 'Authorized Backup Admin'})\n'
                            '• Former Administrator (${config.primaryAdminEmail}) will be DEACTIVATED.\n'
                            '• Historical approvals, orders, and audits remain permanently intact.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFECACA),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Emergency Reason *',
                      style: GoogleFonts.poppins(color: _warmGold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: reasonController.text,
                      dropdownColor: const Color(0xFF2D1414),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF2D1414),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Permanent Medical Incapacitation / Deceased',
                          child: Text('Permanent Medical Incapacitation / Deceased'),
                        ),
                        DropdownMenuItem(
                          value: 'Sudden Executive Departure / Incommunicado',
                          child: Text('Sudden Executive Departure / Incommunicado'),
                        ),
                        DropdownMenuItem(
                          value: 'Disaster Recovery / Unrecoverable Loss',
                          child: Text('Disaster Recovery / Unrecoverable Loss'),
                        ),
                        DropdownMenuItem(
                          value: 'Court / Legal / Governance Directive',
                          child: Text('Court / Legal / Governance Directive'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) reasonController.text = val;
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Official Reference Document Number *',
                      style: GoogleFonts.poppins(color: _warmGold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: referenceController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. HR-MEMO-2026-004, CERT-INCIDENT-882',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF2D1414),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Reference document is required' : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Continuity Security Verification Key *',
                      style: GoogleFonts.poppins(color: _warmGold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: keyController,
                      obscureText: obscureKey,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter Emergency Security Passphrase',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF2D1414),
                        suffixIcon: IconButton(
                          icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18),
                          onPressed: () => setModalState(() => obscureKey = !obscureKey),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _primaryGold.withValues(alpha: 0.4)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Security key is required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await Supabase.instance.client.auth.signOut();
                    },
              child: Text(
                'Cancel & Sign Out',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);

                      final initiatedName = displayName.isNotEmpty ? displayName : 'Authorized Successor';

                      final res = await AdminContinuityService.executeEmergencySuccession(
                        emergencyReason: reasonController.text.trim(),
                        referenceDocument: referenceController.text.trim(),
                        verificationKeyInput: keyController.text.trim(),
                        initiatedByEmail: email,
                        initiatedByName: initiatedName,
                      );

                      if (mounted) {
                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          GlobalMessenger.showSuccess(
                            res['message'] ?? 'Emergency succession executed! You are now Primary Administrator.',
                          );
                          // Proceed directly to admin dashboard
                          await _redirectByUserRole(email, 'admin', initiatedName);
                        } else {
                          setModalState(() => isSubmitting = false);
                          GlobalMessenger.showError(res['message'] ?? 'Emergency succession failed.');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Authorize & Take Over as Primary Admin',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
