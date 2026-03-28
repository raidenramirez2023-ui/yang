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
  bool _isSessionChecking = true; // New flag to handle initial redirect smoothly
  bool _isRedirecting = false;
  bool _rememberMe = false;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb 
      ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com' // Web Client ID
      : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Android Client ID
  );


  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _loadStoredCredentials();
    
    // Listen for auth state changes for real-time redirects after OAuth login.
    //
    // On mobile  → Supabase fires [AuthChangeEvent.signedIn] after deep-link.
    // On web     → Supabase fires [AuthChangeEvent.initialSession] after the
    //              page reloads from the Facebook/Google OAuth redirect.
    //
    // We only act on OAuth sessions (provider != 'email') so that regular
    // email/password logins are handled exclusively by [handleLogin()].
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) return;

      final isOAuthEvent =
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession;

      // Distinguish OAuth logins from email/password logins.
      final provider =
          session.user.appMetadata['provider']?.toString() ?? 'email';
      final isOAuthProvider = provider != 'email';

      if (isOAuthEvent && isOAuthProvider) {
        debugPrint(
          'OAuth: ${data.event} detected — provider: $provider',
        );
        _handleOAuthSuccess(session);
      }
    });
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
      // Delegate to the common success handler to ensure database sync and correct redirect
      _handleOAuthSuccess(session);
      return;
    }

    // No session found, show login form
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

        debugPrint('User not found in users table, checking if it\'s a customer');

        

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

        } else if (email == 'chefycp@gmail.com' || email == 'chefycp.gmail.com') {

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

            "Welcome back, customer!",

            Colors.green.shade700,

            Icons.check_circle_outline,

          );



          if (mounted) {

            Navigator.pushReplacementNamed(context, '/customer-dashboard');

          }

        }

      } else {

        String userRole = userResponse['role']?.toString().toLowerCase() ?? 'staff';

        debugPrint('User role found: $userRole');



        _showSnackBar(

          "Login successful as $userRole!",

          Colors.green.shade700,

          Icons.check_circle_outline,

        );



        if (mounted) {

          _redirectByUserRole(email, userRole);

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
          redirectTo: Uri.base.origin,
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        // Mobile: Use native Google Sign-In SDK
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the sign-in
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Google Sign-In Error: $e", Colors.red.shade700, Icons.error_outline);
      }
    } finally {
      // Don't set isLoading to false if we are redirecting
      if (mounted && !_isRedirecting) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Triggers Facebook OAuth login via Supabase.
  /// - On web: redirects to the current origin so the browser handles the callback.
  /// - On mobile: uses the Android/iOS deep-link scheme so the app is re-opened.
  /// After login, the [onAuthStateChange] listener fires → [_handleOAuthSuccess].
  Future<void> signInWithFacebook() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      if (kIsWeb) {
        // Web: sign out any stale session first, then redirect in the same tab.
        // Supabase will redirect back to the current origin after Facebook login.
        await supabase.auth.signOut();
        await supabase.auth.signInWithOAuth(
          OAuthProvider.facebook,
          redirectTo: Uri.base.origin,
        );
      } else {
        // Mobile (Android / iOS): use the custom deep-link scheme registered
        // in AndroidManifest.xml (and Info.plist on iOS) so that Facebook can
        // redirect back into the app after a successful login.
        //   • Supabase Dashboard → Auth → URL Configuration → Redirect URLs
        //     must also include: io.supabase.flutter://login-callback/
        await supabase.auth.signInWithOAuth(
          OAuthProvider.facebook,
          redirectTo: 'io.supabase.flutter://login-callback/',
        );
      }

      // At this point the browser / in-app WebView has been launched.
      // Session detection + navigation is handled by the
      // onAuthStateChange listener in initState → _handleOAuthSuccess().
    } on AuthException catch (e) {
      debugPrint('Facebook Sign-In AuthException: ${e.message}');
      if (mounted) {
        final message = switch (e.message.toLowerCase()) {
          String m when m.contains('cancelled') || m.contains('canceled') =>
            'Facebook sign-in was cancelled.',
          String m when m.contains('network') =>
            'Network error. Please check your connection and try again.',
          _ => 'Facebook sign-in failed: ${e.message}',
        };
        _showSnackBar(message, Colors.red.shade700, Icons.error_outline);
      }
    } catch (e) {
      debugPrint('Facebook Sign-In error: $e');
      if (mounted) {
        // Handle user-cancelled flow (plugin throws PlatformException on cancel)
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('cancel') || errorStr.contains('user_cancelled')) {
          _showSnackBar(
            'Facebook sign-in was cancelled.',
            Colors.orange.shade700,
            Icons.cancel_outlined,
          );
        } else if (errorStr.contains('network') || errorStr.contains('socket')) {
          _showSnackBar(
            'Network error. Please check your connection.',
            Colors.red.shade700,
            Icons.wifi_off_outlined,
          );
        } else {
          _showSnackBar(
            'An unexpected error occurred. Please try again.',
            Colors.red.shade700,
            Icons.error_outline,
          );
        }
      }
    } finally {
      // Only reset loading if we are NOT about to redirect.
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
      _showSnackBar("OAuth Error: No email found in your Facebook account.", Colors.red.shade700, Icons.error_outline);
      return;
    }

    _isRedirecting = true;
    if (mounted) {
      setState(() {
        _isSessionChecking = true;
        _isLoading = true;
      });
      _showSnackBar(
        "Facebook Sync: $email",
        Colors.blue.shade700,
        Icons.sync,
      );
    }

    try {
      debugPrint('OAuth: Syncing $email with database...');
      // Check if user exists in the users table
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role, avatar_url')
          .eq('email', email)
          .maybeSingle();

      debugPrint('OAuth: Database response: $userResponse');

      final metadata = session.user.userMetadata ?? {};
      final name = metadata['full_name']?.toString() ??
          metadata['name']?.toString() ??
          'Customer';
      final avatarUrl = metadata['avatar_url']?.toString() ?? 
                       metadata['picture']?.toString();

      if (userResponse == null) {
        debugPrint('OAuth: Registering new user: $name ($email)');
        _showSnackBar("New account detected, registering...", Colors.blue.shade700, Icons.person_add);
        
        // Create new user with 'customer' role
        await Supabase.instance.client.from('users').insert({
          'email': email,
          'role': 'customer',
          'name': name,
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
        // Update existing user if avatar_url changed or is missing
        if (avatarUrl != null && userResponse['avatar_url'] != avatarUrl) {
          await Supabase.instance.client
              .from('users')
              .update({'avatar_url': avatarUrl, 'name': name})
              .eq('email', email);
        }

        String userRole =
            userResponse['role']?.toString().toLowerCase() ?? 'customer';
        debugPrint('OAuth: Existing user found with role: $userRole');
        
        if (mounted) {
          _showSnackBar("Redirecting to your dashboard...", Colors.blue.shade700, Icons.arrow_forward);
          _redirectByUserRole(email, userRole);
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
          "Facebook Auth Error: $e",
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

              Text('Checking authentication...', style: TextStyle(color: AppTheme.primaryColor)),

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
                // Logo outside the container
                Image.asset(
                  'assets/images/new-ycplogo.png', // Assuming new-ycplogo.png is the logo shown in the latest image which has transparency
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to mobile-logo if ycplogo doesn't match
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
                        'Login',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
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
          'Email',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your Email',
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
              borderSide: const BorderSide(color: Color(0xFFE81E0D)), // Refined red color
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
            onPressed: _isLoading ? null : handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEE2A12), // Vibrant red matching screenshot
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
                  'Login',
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

        // Social Icons list
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(
              child: Image.asset('assets/images/glogo.png', width: 20, height: 20),
              onTap: _isLoading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(width: 16),
            _buildSocialIcon(
              child: Icon(Icons.facebook, size: 24, color: Colors.blue.shade700),
              onTap: _isLoading ? null : signInWithFacebook,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Sign Up Link
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : () {
              Navigator.pushNamed(context, '/register');
            },
            child: RichText(
              text: const TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: 'Sign up',
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

              : const Text('Sign In'),

          ),

        ),

        const SizedBox(height: 16),



        // Register Button

        SizedBox(

          width: double.infinity,

          child: OutlinedButton(

            onPressed: _isLoading ? null : () {

              Navigator.pushNamed(context, '/register');

            },

            style: OutlinedButton.styleFrom(

              padding: const EdgeInsets.symmetric(vertical: 16),

              side: BorderSide(color: AppTheme.primaryColor),

            ),

            child: Text(

              'Create New Account',

              style: TextStyle(

                color: AppTheme.primaryColor,

                fontWeight: FontWeight.w600,

              ),

            ),

          ),

        ),

        const SizedBox(height: 16),



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

                color: AppTheme.primaryColor,

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
