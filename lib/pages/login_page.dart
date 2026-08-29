import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
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
  // Diagnostic: MethodChannel to get app's actual signing certificate SHA-1
  static const _certChannel = MethodChannel('com.ycprms.yang_chow/certificate');
  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // NOTE: Do NOT set clientId for Android — it's read automatically from google-services.json.
    // Setting a clientId (especially iOS) on Android causes DEVELOPER_ERROR (code 10).
    clientId: kIsWeb
        ? '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com' // Web Client ID only
        : null, // Android: must be null — handled by google-services.json
    serverClientId: '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Web Client ID - required for idToken on Android
  );

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _loadStoredCredentials();

    // Only add auth listener for web OAuth redirects
    if (kIsWeb) {
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          final session = data.session;
          if (session == null || !mounted) return;

          final provider =
              session.user.appMetadata['provider']?.toString() ?? 'email';

          // Only handle OAuth events on web
          if (provider != 'email' && data.event == AuthChangeEvent.signedIn) {
            debugPrint('Web OAuth detected: $provider');
            _handleOAuthSuccess(session);
          }
        },
        onError: (error) {
          debugPrint('Auth state error: $error');
          // Handle PKCE code verifier errors gracefully
          if (error.toString().contains('Code verifier')) {
            if (mounted) {
              setState(() {
                _isSessionChecking = false;
                _isLoading = false;
              });
              _showSnackBar(
                "Sign-in session expired. Please try signing in again.",
                Colors.orange.shade700,
                Icons.refresh,
              );
            }
          }
        },
      );
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
            Navigator.pushReplacementNamed(context, '/customer/dashboard');
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
          Navigator.pushReplacementNamed(context, '/customer/dashboard');
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
      // Ensure Supabase is initialized before attempting sign-in
      try {
        Supabase.instance.client;
      } catch (_) {
        _showSnackBar(
          "Still connecting to server. Please wait a moment and try again.",
          Colors.orange.shade700,
          Icons.wifi_off,
        );
        setState(() => _isLoading = false);
        return;
      }

      if (kIsWeb) {
        // Web: Use OAuth redirect flow
        // Note: Don't call signOut() here — it clears the PKCE code_verifier
        // from localStorage, causing "Code verifier could not be found" errors
        // when Google redirects back to the app.
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: '${Uri.base.origin}/#/login',
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        // Mobile: Use native Google Sign-In SDK with timeout for slow connections
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .signIn()
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException(
                  'Google Sign-In timed out. Please check your internet connection.',
                );
              },
            );
        if (googleUser == null) {
          // User cancelled the sign-in
          setState(() => _isLoading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser
            .authentication
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Token exchange timed out. Please check your internet connection.',
                );
              },
            );
        final String? idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception(
            'Failed to get ID token from Google Sign-In. Please try again.',
          );
        }

        // Sign in with Supabase using the ID token
        await Supabase.instance.client.auth
            .signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: googleAuth.accessToken,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Server authentication timed out. Please check your internet connection.',
                );
              },
            );

        // Handle success directly
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && mounted) {
          _handleOAuthSuccess(session);
        }
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        _showSnackBar(
          e.message ?? 'Connection timed out. Please try again.',
          Colors.orange.shade700,
          Icons.wifi_off,
        );
      }
    } catch (e) {
      if (mounted) {
        // DIAGNOSTIC: Show actual app SHA-1 alongside the error
        String sha1Info = '';
        if (!kIsWeb) {
          try {
            final sha1 = await _certChannel.invokeMethod<String>('getSHA1');
            sha1Info = '\nApp SHA-1: $sha1';
          } catch (_) {
            sha1Info = '\nApp SHA-1: (could not retrieve)';
          }
        }
        _showSnackBar(
          "Google Sign-In Error: $e$sha1Info",
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
      _showSnackBar("Google Sync: $email", Colors.blue.shade700, Icons.sync);
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
          Navigator.pushReplacementNamed(context, '/customer/dashboard');
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
          Navigator.pushReplacementNamed(context, '/customer/dashboard');
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

  // ─── Yang Chow Standard Red & Gold Theme Palette ───────────────────
  static const Color _forestGreen = Color(0xFF990000); // dark red
  static const Color _activeEmerald = Color(0xFFAA0000); // medium red
  static const Color _warmGold = Color(0xFFFFD166); // warm gold accent
  static const Color _primaryGold = Color(0xFFC9922E); // amber gold
  static const Color _darkForest = Color(0xFF770000); // darkest red
  static const Color _deepBurgundy = Color(0xFF380202); // deep wine burgundy

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

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
                'Checking authentication...',
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
          // Subtle ambient gold glow top-right
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
          // Subtle ambient red-gold glow bottom-left
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
                            'AUTHENTIC CHINESE RESTAURANT',
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
                                _buildFeatureBadge(Icons.restaurant, 'Chinese Specialties'),
                                _buildFeatureBadge(Icons.alarm_on, 'Advance Ordering'),
                                _buildFeatureBadge(Icons.celebration, 'Event Reservation'),
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
                              // Top Gradient Bar
                              Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _primaryGold,
                                      _warmGold,
                                      _forestGreen,
                                    ],
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
                const Icon(Icons.person_pin, size: 15, color: _forestGreen),
                const SizedBox(width: 6),
                Text(
                  'CUSTOMER LOGIN',
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
          'Welcome Back',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF330505),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to access your orders & reservations',
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
          'Email Address',
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
            onSubmitted: (_) => _isLoading ? null : handleLogin(),
            decoration: InputDecoration(
              hintText: 'e.g. customer@gmail.com',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFCFAF7),
              prefixIcon: const Icon(
                Icons.email_outlined,
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
            onSubmitted: (_) => _isLoading ? null : handleLogin(),
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
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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

        // Remember Me & Forgot Password (Responsive Row/Flexible)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() => _rememberMe = value ?? false),
                      activeColor: _forestGreen,
                      checkColor: _warmGold,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Remember Me',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
        const SizedBox(height: 22),

        // Login Button with Red & Gold Gradient
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
              onTap: _isLoading ? null : handleLogin,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _warmGold,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'LOGIN',
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
        const SizedBox(height: 20),

        // OR Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR CONTINUE WITH',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 20),

        // Google Sign In Button
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: Image.asset('assets/images/glogo.png', height: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Sign in with Google',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _primaryGold.withOpacity(0.45), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: const Color(0xFFFCFAF7),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Sign Up Footer
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/register'),
              child: Text(
                'Sign Up',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: _forestGreen,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _forestGreen,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
