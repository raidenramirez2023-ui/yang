import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _isRedirecting = false;
  bool _rememberMe = false;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb 
      ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com'
      : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _loadStoredCredentials();
    
    // Listen for auth state changes for OAuth login
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) return;

      final isOAuthEvent =
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession;

      final provider =
          session.user.appMetadata['provider']?.toString() ?? 'email';
      final isOAuthProvider = provider != 'email';

      if (isOAuthEvent && isOAuthProvider) {
        debugPrint('OAuth: ${data.event} detected — provider: $provider');
        _handleOAuthSuccess(session);
      }
    });
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
      _handleOAuthSuccess(session);
      return;
    }

    if (mounted) {
      setState(() => _isSessionChecking = false);
    }
  }

  void _redirectStaffUser(String email, String userRole) {
    if (!mounted) return;

    // Only allow staff users to login from this page
    if (email.toLowerCase() == 'staffycp@gmail.com' || userRole == 'staff') {
      Navigator.pushReplacementNamed(context, '/staff-dashboard');
    } else {
      _showSnackBar(
        "This login page is for staff only. Please use the main login page.",
        Colors.red.shade700,
        Icons.error_outline,
      );
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

    // Restrict to staff email only
    if (email.toLowerCase() != 'staffycp@gmail.com') {
      _showSnackBar(
        "This login page is only for staffycp@gmail.com",
        Colors.red.shade700,
        Icons.error_outline,
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

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', email)
          .maybeSingle();

      debugPrint('User response from database: $userResponse');

      if (userResponse == null) {
        debugPrint('Staff user not found, creating staff account');
        
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'role': 'staff',
        });

        _showSnackBar(
          "Staff account created successfully!",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/staff-dashboard');
        }
      } else {
        String userRole = userResponse['role']?.toString().toLowerCase() ?? 'staff';
        debugPrint('User role found: $userRole');

        _showSnackBar(
          "Staff login successful!",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        if (mounted) {
          _redirectStaffUser(email, userRole);
        }
      }
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          errorMessage = 'Invalid email or password';
          break;
        case 'email not confirmed':
          errorMessage = 'Email not confirmed. Please register again to activate your account.';
          break;
        case 'user not found':
          errorMessage = 'No staff user found with this email';
          break;
        default:
          errorMessage = 'Staff login failed: ${e.message}';
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signOut();
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Failed to get ID token from Google Sign-In');
        }

        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Google Sign-In Error: $e", Colors.red.shade700, Icons.error_outline);
      }
    } finally {
      if (mounted && !_isRedirecting) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOAuthSuccess(Session session) async {
    if (_isRedirecting) {
      debugPrint('OAuth: Already redirecting, skipping...');
      return;
    }

    final email = session.user.email;
    if (email == null) {
      debugPrint('OAuth: No email found in session.');
      _showSnackBar("OAuth Error: No email found in your account.", Colors.red.shade700, Icons.error_outline);
      return;
    }

    // Restrict OAuth login to staff email only
    if (email.toLowerCase() != 'staffycp@gmail.com') {
      _showSnackBar(
        "This login page is only for staffycp@gmail.com",
        Colors.red.shade700,
        Icons.error_outline,
      );
      return;
    }

    _isRedirecting = true;
    if (mounted) {
      setState(() {
        _isSessionChecking = true;
        _isLoading = true;
      });
      _showSnackBar(
        "Staff OAuth Sync: $email",
        Colors.blue.shade700,
        Icons.sync,
      );
    }

    try {
      debugPrint('OAuth: Syncing staff user $email with database...');
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role, avatar_url')
          .eq('email', email)
          .maybeSingle();

      debugPrint('OAuth: Database response: $userResponse');

      final metadata = session.user.userMetadata ?? {};
      final name = metadata['full_name']?.toString() ?? 
                  metadata['name']?.toString() ?? 
                  'Staff';
      final avatarUrl = metadata['avatar_url']?.toString() ?? 
                       metadata['picture']?.toString();

      if (userResponse == null) {
        debugPrint('OAuth: Registering new staff user: $name ($email)');
        _showSnackBar("New staff account detected, registering...", Colors.blue.shade700, Icons.person_add);
        
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'role': 'staff',
          'name': name,
          'avatar_url': avatarUrl,
        });

        debugPrint('OAuth: Successfully registered staff. Navigating...');
        if (mounted) {
          _showSnackBar(
            "Welcome to Staff Portal!",
            Colors.green.shade700,
            Icons.check_circle_outline,
          );
          Navigator.pushReplacementNamed(context, '/staff-dashboard');
        }
      } else {
        if (avatarUrl != null && userResponse['avatar_url'] != avatarUrl) {
          await Supabase.instance.client
              .from('users')
              .update({'avatar_url': avatarUrl, 'name': name})
              .eq('email', email);
        }

        String userRole = userResponse['role']?.toString().toLowerCase() ?? 'staff';
        debugPrint('OAuth: Existing staff user found with role: $userRole');
        
        if (mounted) {
          _showSnackBar("Redirecting to staff dashboard...", Colors.blue.shade700, Icons.arrow_forward);
          _redirectStaffUser(email, userRole);
        }
      }
    } catch (e) {
      debugPrint('OAuth Error: $e');
      if (mounted) {
        setState(() {
          _isSessionChecking = false;
          _isLoading = false;
          _isRedirecting = false;
        });
        _showSnackBar(
          "Staff OAuth Error: $e",
          Colors.red.shade700,
          Icons.error_outline,
        );
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
                // Logo
                Image.asset(
                  'assets/images/new-ycplogo.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/mobile-logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(height: 120),
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
                        'Staff Login',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Staff Portal Only',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      _buildMobileLoginForm(),
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

  Widget _buildMobileLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Label
        const Text(
          'Staff Email',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'staffycp@gmail.com',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.email_outlined, color: Colors.red.shade700),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

        // Password Label
        const Text(
          'Password',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your Password', 
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline, color: Colors.red.shade700),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.red.shade700,
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
        const SizedBox(height: 16),

        // Remember Me Checkbox
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: _isLoading ? null : (bool? value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
              },
              activeColor: const Color(0xFFE81E0D),
            ),
            const Text(
              'Remember me',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
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
                color: Color(0xFFE81E0D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Login Button
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
            onPressed: _isLoading ? null : handleStaffLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEE2A12),
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
                  'Staff Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
          ),
        ),
        const SizedBox(height: 32),

        // Or continue with row
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 24),

        // Social Icons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(
              child: Image.asset('assets/images/glogo.png', width: 20, height: 20),
              onTap: _isLoading ? null : _handleGoogleSignIn,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Back to Main Login Link
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: RichText(
              text: const TextSpan(
                text: 'Need admin access? ',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: 'Main Login',
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

  Widget _buildSocialIcon({required Widget child, Color? backgroundColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Staff Login',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Staff Portal Only',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email Field
        Text(
          'Staff Email',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'staffycp@gmail.com',
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
        const SizedBox(height: 16),

        // Remember Me
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: _isLoading ? null : (bool? value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),
            const Text('Remember me'),
          ],
        ),
        const SizedBox(height: 16),

        // Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleStaffLogin,
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
              : const Text('Staff Login'),
          ),
        ),
        const SizedBox(height: 16),

        // Back to Main Login
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppTheme.primaryColor),
            ),
            child: Text(
              'Back to Main Login',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
