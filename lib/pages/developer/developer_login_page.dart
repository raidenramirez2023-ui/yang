import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'developer_theme.dart';

class DeveloperLoginPage extends StatefulWidget {
  const DeveloperLoginPage({super.key});

  @override
  State<DeveloperLoginPage> createState() => _DeveloperLoginPageState();
}

class _DeveloperLoginPageState extends State<DeveloperLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('dev_remember_me') ?? false;
      if (remember) {
        final email = prefs.getString('dev_saved_email') ?? '';
        final pass = prefs.getString('dev_saved_pass') ?? '';
        if (mounted) {
          setState(() {
            _rememberMe = true;
            _emailController.text = email;
            _passwordController.text = pass;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _checkActiveSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session != null && user != null) {
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('email', user.email!)
            .maybeSingle();

        final role = res?['role']?.toString().toLowerCase() ?? '';
        if (role == 'developer') {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/developer/dashboard');
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _handleDeveloperLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both developer email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // 1. Authenticate with Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Invalid login credentials.');
      }

      // 2. Strict Role Verification in public.users
      final userRecord = await supabase
          .from('users')
          .select('role, firstname, lastname')
          .eq('email', email)
          .maybeSingle();

      final role = userRecord?['role']?.toString().toLowerCase() ?? '';

      if (role != 'developer') {
        // Sign them out immediately to block non-developer accounts
        await supabase.auth.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'ACCESS DENIED: Account "$email" does not have the "developer" role.';
          });
        }
        return;
      }

      // 3. Save Remember Me credentials if requested
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('dev_remember_me', true);
        await prefs.setString('dev_saved_email', email);
        await prefs.setString('dev_saved_pass', password);
      } else {
        await prefs.remove('dev_remember_me');
        await prefs.remove('dev_saved_email');
        await prefs.remove('dev_saved_pass');
      }

      // 4. Redirect to Developer Dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/developer/dashboard');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeveloperTheme.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            decoration: DeveloperTheme.cardDecoration(
              borderRadius: 16,
              glow: true,
              glowColor: DeveloperTheme.accentIndigo,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Terminal / Shield Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentIndigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DeveloperTheme.accentIndigo.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.terminal_rounded,
                      color: DeveloperTheme.accentIndigo,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Center(
                  child: Text(
                    'IT Developer Console',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DeveloperTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Technical Maintenance & Diagnostics Portal',
                    style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                  ),
                ),

                const SizedBox(height: 24),

                // Security Isolation Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, size: 14, color: DeveloperTheme.accentEmerald),
                      const SizedBox(width: 8),
                      Text(
                        'Restricted: Developer Role Authorization Required',
                        style: DeveloperTheme.monoText(
                          fontSize: 10,
                          color: DeveloperTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DeveloperTheme.accentRose.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: DeveloperTheme.accentRose),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, color: DeveloperTheme.accentRose),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                Text('Developer Email', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 14, color: DeveloperTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'developer@yangchow.com',
                    hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: DeveloperTheme.textMuted),
                    filled: true,
                    fillColor: DeveloperTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field
                Text('Developer Password', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _handleDeveloperLogin(),
                  style: GoogleFonts.inter(fontSize: 14, color: DeveloperTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    prefixIcon: const Icon(Icons.key_rounded, size: 18, color: DeveloperTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: DeveloperTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: DeveloperTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.accentIndigo),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Remember Me
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: DeveloperTheme.accentIndigo,
                        checkColor: Colors.white,
                        side: const BorderSide(color: DeveloperTheme.borderSubtle),
                        onChanged: (val) => setState(() => _rememberMe = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Remember credentials', style: DeveloperTheme.bodySmall()),
                  ],
                ),

                const SizedBox(height: 24),

                // Sign In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleDeveloperLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeveloperTheme.accentIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Sign In to Developer Console',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 24),

                // Return to App Links
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: DeveloperTheme.textMuted),
                    label: Text(
                      'Return to Restaurant Homepage',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
