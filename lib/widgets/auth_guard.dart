import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_settings_service.dart';
import '../services/admin_continuity_service.dart';
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
  // Tracks if the authenticated developer is visiting a non-developer route
  bool _isDeveloperTesting = false;
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
          .ilike('email', user.email!)
          .maybeSingle();
      if (userResponse == null) {
        debugPrint('🔒 AuthGuard: User not found in database, redirecting');
        _redirectToLogin();
        return;
      }
      final userRole = userResponse['role']?.toString().toLowerCase() ?? '';

      // ─── Developer / IT Superuser Bypass ─────────────────────────────────────
      // The authenticated Developer account always bypasses:
      //   • Maintenance Mode restrictions (system remains in maintenance for all
      //     other users — only the developer can pass through)
      //   • allowedRoles checks (developer can access staff, customer, admin,
      //     chef, inventory pages for testing and debugging purposes)
      //
      // This does NOT change the developer's actual DB role. The developer logs
      // in with their own credentials and is tracked in audit logs as 'developer'.
      // ─────────────────────────────────────────────────────────────────────────
      if (userRole == 'developer') {
        debugPrint('🔧 AuthGuard: Developer superuser — granting full access to ${widget.child.runtimeType} (maintenance bypass)');
        // Show the floating "← Dev Console" overlay when visiting non-developer routes.
        final isDevRoute = widget.allowedRoles?.contains('developer') ?? false;
        if (mounted) {
          setState(() {
            _isAuthorized = true;
            _isChecking = false;
            _isDeveloperTesting = !isDevRoute;
          });
        }
        return;
      }

      // Security Check: Block deactivated accounts across all protected routes
      final isDeactivated = await AdminContinuityService.isAccountDeactivated(user.email!);
      if (isDeactivated) {
        debugPrint('🔒 AuthGuard: User ${user.email} is deactivated. Signing out.');
        await Supabase.instance.client.auth.signOut();
        _redirectToLogin();
        return;
      }

      // Check Maintenance Mode: Block non-developer and non-admin roles when maintenance is active.
      // Admin has limited restricted access within the admin portal during maintenance.
      // Uses a LIVE database query (not the stale in-memory cache) so changes from any
      // device/browser are immediately reflected here.
      if (userRole != 'admin' && userRole != 'backup_admin') {
        final isMaintenance = await AppSettingsService.checkMaintenanceModeFromDB();
        if (isMaintenance) {
          debugPrint('🚧 AuthGuard: Maintenance mode active, redirecting $userRole to /maintenance');
          _redirectToMaintenance();
          return;
        }
      }

      // Continuity Security Check: If route is restricted to admins, check if user is locked in standby
      if (widget.allowedRoles != null &&
          (widget.allowedRoles!.contains('admin') || widget.allowedRoles!.contains('backup_admin'))) {
        final isStandbyLocked = await AdminContinuityService.isBackupAdminLockedInStandby(user.email!);
        if (isStandbyLocked) {
          debugPrint('🔒 AuthGuard: User ${user.email} is Backup Admin locked in STANDBY mode. Blocking admin route.');
          await Supabase.instance.client.auth.signOut();
          _redirectToLogin();
          return;
        }
      }

      final isAllowed = widget.allowedRoles!.contains(userRole) ||
          (widget.allowedRoles!.contains('admin') && userRole == 'backup_admin');

      if (isAllowed) {
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

  void _redirectToMaintenance() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/maintenance');
        }
      });
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

    // ─── Developer Testing Overlay ────────────────────────────────────────────
    // When the authenticated developer visits a non-developer route (staff,
    // customer, admin, chef, inventory), overlay a persistent floating badge so
    // they can return to the Developer Console with a single tap — no URL typing,
    // no browser back button needed.
    // ─────────────────────────────────────────────────────────────────────────
    if (_isDeveloperTesting) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            top: 12,
            left: 12,
            child: _DeveloperTestingBadge(
              onBack: () => Navigator.of(context)
                  .pushReplacementNamed('/developer/dashboard'),
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}

/// A compact floating badge shown when the Developer/IT account is testing
/// a non-developer portal (staff, customer, admin, chef, inventory).
/// Tapping it returns the developer to the Developer Console.
/// Auto-collapses after 4 seconds to minimise UI interference; tap to re-expand.
class _DeveloperTestingBadge extends StatefulWidget {
  final VoidCallback onBack;
  const _DeveloperTestingBadge({required this.onBack});

  @override
  State<_DeveloperTestingBadge> createState() => _DeveloperTestingBadgeState();
}

class _DeveloperTestingBadgeState extends State<_DeveloperTestingBadge>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _animController;
  late Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _widthAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Auto-collapse after 4 seconds to minimise UI interference
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _expanded = false);
        _animController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          if (_expanded) {
            widget.onBack();
          } else {
            // Re-expand on tap when collapsed
            setState(() => _expanded = true);
            _animController.forward();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.terminal, size: 15, color: Color(0xFF818CF8)),
              if (_expanded) ...[  
                const SizedBox(width: 8),
                SizeTransition(
                  sizeFactor: _widthAnim,
                  axis: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DEV MODE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF818CF8),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 14,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 13,
                        color: Color(0xFFA5B4FC),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Dev Console',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFA5B4FC),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
