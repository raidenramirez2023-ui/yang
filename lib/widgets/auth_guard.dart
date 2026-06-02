import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
/// A widget that protects routes by checking for a valid Supabase session.
///
/// If the user is not authenticated (no active session), they are redirected
/// to the landing page ('/') immediately. This prevents unauthorized access
/// when someone copies and pastes a URL into another window, tab, or incognito.
///
/// Optionally, you can specify [allowedRoles] to restrict access to users
/// with specific roles (e.g., 'admin', 'staff', 'customer').
/// If [allowedRoles] is null or empty, any authenticated user can access the page.
class AuthGuard extends StatefulWidget {
  final Widget child;
  final List<String>? allowedRoles;
  final String redirectRoute;
  const AuthGuard({
    super.key,
    required this.child,
    this.allowedRoles,
    this.redirectRoute = '/',
  });
  @override
  State<AuthGuard> createState() => _AuthGuardState();
}
class _AuthGuardState extends State<AuthGuard> {
  bool _isChecking = true;
  bool _isAuthorized = false;
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }
  Future<void> _checkAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      // No session or no user = not authenticated
      if (session == null || user == null) {
        debugPrint('🔒 AuthGuard: No session found, redirecting to ${widget.redirectRoute}');
        _redirectToLogin();
        return;
      }
      // If no role restriction, any authenticated user is allowed
      if (widget.allowedRoles == null || widget.allowedRoles!.isEmpty) {
        if (mounted) {
          setState(() {
            _isAuthorized = true;
            _isChecking = false;
          });
        }
        return;
      }
      // Check user role from the database
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();
      if (userResponse == null) {
        debugPrint('🔒 AuthGuard: User not found in database, redirecting');
        _redirectToLogin();
        return;
      }
      final userRole = userResponse['role']?.toString().toLowerCase() ?? '';
      if (widget.allowedRoles!.contains(userRole)) {
        if (mounted) {
          setState(() {
            _isAuthorized = true;
            _isChecking = false;
          });
        }
      } else {
        debugPrint('🔒 AuthGuard: User role "$userRole" not in allowed roles ${widget.allowedRoles}');
        _redirectToLogin();
      }
    } catch (e) {
      debugPrint('🔒 AuthGuard: Error checking auth: $e');
      _redirectToLogin();
    }
  }
  void _redirectToLogin() {
    if (mounted) {
      // Use a post-frame callback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(widget.redirectRoute);
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFB71C1C),
              ),
              SizedBox(height: 16),
              Text(
                'Verifying access...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isAuthorized) {
      // Show nothing while redirecting
      return const Scaffold(body: SizedBox.shrink());
    }
    return widget.child;
  }
}
