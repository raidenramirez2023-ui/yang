import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSessionChecking =
      true; // New flag to handle initial redirect smoothly
  bool _isRedirecting = false;
  bool _rememberMe = false;
  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com' // Web Client ID
        : '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com', // iOS Client ID (adjust based on platform if needed)
  );

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _loadStoredCredentials();

    // Only add auth listener for web OAuth redirects
    if (kIsWeb) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session == null || !mounted) return;

        final provider =
            session.user.appMetadata['provider']?.toString() ?? 'email';

        // Only handle OAuth events on web
        if (provider != 'email' && data.event == AuthChangeEvent.signedIn) {
          debugPrint('Web OAuth detected: $provider');
          _handleOAuthSuccess(session);
        }
      });
    }
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe) {
        if (mounted) {
          setState(() {
            _rememberMe = true;
            emailController.text = prefs.getString('email') ?? '';
            passwordController.text = prefs.getString('password') ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    }
  }

  Future<void> _checkInitialSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null && session.user.email != null) {
      debugPrint('Login: Initial session found for ${session.user.email}');

      // Check user role in database
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', session.user.email!)
          .maybeSingle();

      if (userResponse != null) {
        String userRole =
            userResponse['role']?.toString().toLowerCase() ?? 'customer';

        // If staff user detected in customer login, redirect to staff portal
        if (userRole != 'customer') {
          debugPrint(
            'Initial session: Staff user detected, redirecting to staff portal',
          );
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/staff-login');
          }
          return;
        }
      }

      // Delegate to the common success handler for customers
      _handleOAuthSuccess(session);
      return;
    }

    // No session found, show login form
    if (mounted) {
      setState(() => _isSessionChecking = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  Future<void> handleLogin() async {
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

      // Save remember me credentials AFTER auth success
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('email', email);
        await prefs.setString('password', password);
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('email');
        await prefs.remove('password');
      }

      debugPrint('=== LOGIN DEBUG ===');

      debugPrint('Email: $email');

      debugPrint('Auth successful');

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', email)
          .maybeSingle();

      debugPrint('User response from database: $userResponse');

      if (userResponse == null) {
        debugPrint(
          'User not found in users table, checking if it\'s a customer',
        );

        if (email == 'adm.pagsanjan@gmail.com') {
          await Supabase.instance.client.from('users').insert({
            'email': email,

            'role': 'admin',
          });

          _showSnackBar(
            "Admin account created successfully!",

            Colors.green.shade700,

            Icons.check_circle_outline,
          );

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else if (email == 'chefycp@gmail.com' ||
            email == 'chefycp.gmail.com') {
          await Supabase.instance.client.from('users').insert({
            'email': email,

            'role': 'chef',
          });

          _showSnackBar(
            "Chef account created successfully!",

            Colors.green.shade700,

            Icons.check_circle_outline,
          );

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/chef-dashboard');
          }
        } else {
          // If not in users table, treat as customer

          debugPrint('Treating as customer account');

          _showSnackBar(
            "Welcome back, ${email.split('@')[0]}!",

            Colors.green.shade700,

            Icons.check_circle_outline,
          );

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/customer-dashboard');
          }
        }
      } else {
        String userRole =
            userResponse['role']?.toString().toLowerCase() ?? 'staff';

        debugPrint('User role found: $userRole');

        // Check if user is staff - if yes, block and redirect to staff portal
        if (userRole != 'customer') {
          debugPrint('Staff user detected in customer login, blocking access');
          await Supabase.instance.client.auth.signOut(); // Sign them out

          _showSnackBar(
            "Staff account detected. Please use the Staff Portal to login.",
            Colors.orange.shade700,
            Icons.admin_panel_settings,
          );

          if (mounted) {
            // Redirect to staff portal after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/staff-login');
              }
            });
          }
          return;
        }

        debugPrint('Customer user verified, allowing access');

        _showSnackBar(
          "Welcome back, ${email.split('@')[0]}!",
          Colors.green.shade700,
          Icons.check_circle_outline,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/customer-dashboard');
        }
      }
    } on AuthException catch (e) {
      String errorMessage;

      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          errorMessage = 'Invalid email or password';

          break;

        case 'email not confirmed':
          errorMessage =
              'Email not confirmed. Please register again to activate your account.';

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Web: Use OAuth redirect flow
        await Supabase.instance.client.auth.signOut();
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb
              ? '${Uri.base.origin}/#/login'
              : 'io.supabase.flutter://login-callback/',
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        // Mobile: Use native Google Sign-In SDK
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the sign-in
          setState(() => _isLoading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Failed to get ID token from Google Sign-In');
        }

        // Sign in with Supabase using the ID token
        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );

        // Handle success directly
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && mounted) {
          _handleOAuthSuccess(session);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          "Google Sign-In Error: $e",
          Colors.red.shade700,
          Icons.error_outline,
        );
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
      _showSnackBar(
        "OAuth Error: No email found in your Google account.",
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
      _showSnackBar("Facebook Sync: $email", Colors.blue.shade700, Icons.sync);
    }

    try {
      debugPrint('OAuth: Syncing $email with database...');
      // Check if user exists in the users table
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('id, role, avatar_url')
          .eq('email', email)
          .maybeSingle();

      debugPrint('OAuth: Database response: $userResponse');

      final metadata = session.user.userMetadata ?? {};
      final name =
          metadata['full_name']?.toString() ??
          metadata['name']?.toString() ??
          'Customer';
      final avatarUrl =
          metadata['avatar_url']?.toString() ?? metadata['picture']?.toString();

      if (userResponse == null) {
        debugPrint('OAuth: Registering new user: $name ($email)');
        _showSnackBar(
          "New account detected, registering...",
          Colors.blue.shade700,
          Icons.person_add,
        );

        // Create new user with 'customer' role
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'role': 'customer',
          'avatar_url': avatarUrl,
        });

        debugPrint('OAuth: Successfully registered. Navigating...');
        if (mounted) {
          _showSnackBar(
            "Welcome to Yang Chow!",
            Colors.green.shade700,
            Icons.check_circle_outline,
          );
          Navigator.pushReplacementNamed(context, '/customer-dashboard');
        }
      } else {
        // Prepare updates for existing user
        final Map<String, dynamic> updates = {};
        final existingAvatarUrl = userResponse['avatar_url']?.toString();
        final existingId = userResponse['id']?.toString();

        if (avatarUrl != null && existingAvatarUrl != avatarUrl) {
          updates['avatar_url'] = avatarUrl;
        }

        // Crucial: Sync the public.users id with the auth.users id
        if (existingId != session.user.id) {
          debugPrint(
            'OAuth: Synchronizing ID mismatch: $existingId -> ${session.user.id}',
          );
          updates['id'] = session.user.id;
        }

        if (updates.isNotEmpty) {
          debugPrint('OAuth: Updating user record: $updates');
          await Supabase.instance.client
              .from('users')
              .update(updates)
              .eq('email', email);
        }

        String userRole =
            userResponse['role']?.toString().toLowerCase() ?? 'customer';
        debugPrint('OAuth: Existing user found with role: $userRole');

        // Check if user is staff - if yes, block and redirect to staff portal
        if (userRole != 'customer') {
          debugPrint(
            'OAuth: Staff user detected in customer login, blocking access',
          );
          await Supabase.instance.client.auth.signOut(); // Sign them out

          _showSnackBar(
            "Staff account detected. Please use the Staff Portal to login.",
            Colors.orange.shade700,
            Icons.admin_panel_settings,
          );

          if (mounted) {
            // Redirect to staff portal after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/staff-login');
              }
            });
          }
          return;
        }

        if (mounted) {
          _showSnackBar(
            "Welcome back, ${session.user.email!.split('@')[0]}!",
            Colors.green.shade700,
            Icons.check_circle_outline,
          );
          Navigator.pushReplacementNamed(context, '/customer-dashboard');
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

        String friendlyError = "OAuth Error: $e";
        if (e.toString().contains('23505') ||
            e.toString().contains('duplicate key')) {
          friendlyError =
              "This account is already being synchronized. Please try refreshing or logging in again.";
        }

        _showSnackBar(friendlyError, Colors.red.shade700, Icons.error_outline);
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
    final isTablet = ResponsiveUtils.isTablet(context);

    if (_isSessionChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                'Checking authentication...',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
            child: Container(color: AppTheme.primaryColor.withValues(alpha: 0.85)),
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    margin: const EdgeInsets.only(right: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 48,
                    ),
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
            child: Container(color: AppTheme.primaryColor.withValues(alpha: 0.85)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                  constraints: const BoxConstraints(maxWidth: 480),
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
            child: Container(color: AppTheme.primaryColor.withValues(alpha: 0.85)),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                'CUSTOMER LOGIN',
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
        SizedBox(
          height: 50,
          child: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Email Address',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(
                Icons.person,
                color: Colors.grey.shade500,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
        ),
        const SizedBox(height: 16),

        // Password Input
        SizedBox(
          height: 50,
          child: TextField(
            controller: passwordController,
            obscureText: !_isPasswordVisible,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(
                Icons.lock,
                color: Colors.grey.shade500,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
        ),
        const SizedBox(height: 16),

        // Remember Me
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _rememberMe = value ?? false),
                activeColor: AppTheme.primaryColor,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Remember Me',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Login Button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Footer Actions corresponding to reference image lower buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/forgot-password'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/register'),
              child: const Text(
                "Don't have an account?",
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ],
        ),
        const SizedBox(height: 24),

        // Google Sign In
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: Image.asset('assets/images/glogo.png', height: 18),
            label: const Text(
              'Sign in with Google',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
