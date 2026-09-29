import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_settings_service.dart';
import '../services/admin_continuity_service.dart';
import '../services/it_access_service.dart';
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

  // ── Maintenance Realtime Watchdog & Graceful Notice ──
  Timer? _maintenanceWatchdogTimer;
  Timer? _graceCountdownTimer;
  bool _isGraceActive = false;
  int _graceSecondsRemaining = 45;
  final ValueNotifier<int> _graceCountdownNotifier = ValueNotifier<int>(45);
  String _maintenanceReason = 'Scheduled technical maintenance and database upgrades';
  bool _hasShownGraceDialog = false;

  // ── Scoped IT Diagnostic & Module Lock Watchdog ──
  Map<String, dynamic>? _activeItLockSession;
  Map<String, dynamic>? _activeItNoticeSession;
  RealtimeChannel? _itAccessRealtimeChannel;
  String _currentUserRole = '';
  bool _itNoticeDismissed = false;
  String? _lastItNoticeId;


  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _maintenanceWatchdogTimer?.cancel();
    _graceCountdownTimer?.cancel();
    _graceCountdownNotifier.dispose();
    if (_itAccessRealtimeChannel != null) {
      Supabase.instance.client.removeChannel(_itAccessRealtimeChannel!);
    }
    super.dispose();
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
        _currentUserRole = userRole;
        if (userRole != 'developer') {
          await _checkItAccessStatus(userRole);
          _setupItAccessRealtime(userRole);
        }
        if (mounted) {
          setState(() {
            _isAuthorized = true;
            _isChecking = false;
          });
          // Start real-time maintenance watchdog for customer & non-admin staff
          if (userRole != 'admin' && userRole != 'backup_admin' && userRole != 'developer') {
            _startMaintenanceWatchdog();
          }
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
    _maintenanceWatchdogTimer?.cancel();
    _graceCountdownTimer?.cancel();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/maintenance');
        }
      });
    }
  }

  void _redirectToLogin() {
    _maintenanceWatchdogTimer?.cancel();
    _graceCountdownTimer?.cancel();
    if (mounted) {
      // Use a post-frame callback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(widget.redirectRoute);
        }
      });
    }
  }

  // ─── Realtime Watchdog & Graceful Notice Handlers ──────────────────────────

  void _startMaintenanceWatchdog() {
    _maintenanceWatchdogTimer?.cancel();
    // Check every 4 seconds to detect maintenance activation in real-time
    _maintenanceWatchdogTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || !_isAuthorized) return;
      try {
        if (_currentUserRole.isNotEmpty && _currentUserRole != 'developer') {
          _checkItAccessStatus(_currentUserRole);
        }
        final isMaintenance = await AppSettingsService.checkMaintenanceModeFromDB();
        if (isMaintenance) {
          if (!_isGraceActive) {
            _fetchMaintenanceReasonAndStartGrace();
          }
        } else {
          // If developer turns maintenance OFF during the grace period, cancel grace!
          if (_isGraceActive) {
            _cancelGracePeriod();
          }
        }
      } catch (e) {
        debugPrint('⚠️ AuthGuard: Error in maintenance watchdog: $e');
      }
    });
  }

  Future<void> _fetchMaintenanceReasonAndStartGrace() async {
    try {
      final res = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'maintenance_reason')
          .maybeSingle();
      final reason = res?['setting_value']?.toString().trim();
      if (reason != null && reason.isNotEmpty) {
        _maintenanceReason = reason;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isGraceActive = true;
      _graceSecondsRemaining = 45;
      _graceCountdownNotifier.value = 45;
      _hasShownGraceDialog = false;
    });

    // Start 1-second countdown
    _graceCountdownTimer?.cancel();
    _graceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_graceSecondsRemaining > 1) {
        _graceSecondsRemaining--;
        _graceCountdownNotifier.value = _graceSecondsRemaining;
      } else {
        timer.cancel();
        _redirectToMaintenance();
      }
    });

    // Show friendly notice modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasShownGraceDialog) {
        _hasShownGraceDialog = true;
        _showGraceNoticeDialog();
      }
    });
  }

  void _cancelGracePeriod() {
    _graceCountdownTimer?.cancel();
    _graceCountdownTimer = null;
    if (mounted) {
      setState(() {
        _isGraceActive = false;
        _graceSecondsRemaining = 45;
        _graceCountdownNotifier.value = 45;
      });
    }
  }

  void _showGraceNoticeDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFFB45309).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subtle Top Accent Strip
                Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFD97706),
                        Color(0xFFEA580C),
                        Color(0xFFB71C1C),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 440;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Responsive Header
                            if (isCompact) ...[
                              // Compact Mobile Header: Top status row + title
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: const Icon(
                                      Icons.published_with_changes_rounded,
                                      color: Color(0xFFB45309),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'SYSTEM MAINTENANCE',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF92400E),
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _graceCountdownNotifier,
                                    builder: (context, seconds, _) {
                                      final isUrgent = seconds <= 10;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 12,
                                              color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${seconds}s',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isUrgent ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scheduled System Maintenance',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ] else ...[
                              // Desktop / Tablet Header: Horizontal inline
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.published_with_changes_rounded,
                                      color: Color(0xFFB45309),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFDC2626),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'SYSTEM MAINTENANCE ADVISORY',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF92400E),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Scheduled System Maintenance',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _graceCountdownNotifier,
                                    builder: (context, seconds, _) {
                                      final isUrgent = seconds <= 10;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 13,
                                              color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${seconds}s',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: isUrgent ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Customer Courteous Notice
                            Text(
                              'Dear Valued Customer, our team is currently performing scheduled system enhancements to ensure higher reliability, speed, and security across Yang Chow.',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 11.5 : 12,
                                color: const Color(0xFF64748B),
                                height: 1.38,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Compact Maintenance Reason Callout
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Activity: ',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _maintenanceReason,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Responsive Status Cards (Stacked on small mobile, 2-column on wider screens)
                            if (isCompact) ...[
                              _buildSecurityCard(),
                              const SizedBox(height: 7),
                              _buildPaymentsPausedCard(),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildSecurityCard()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildPaymentsPausedCard()),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Slim Countdown Progress Bar
                            ValueListenableBuilder<int>(
                              valueListenable: _graceCountdownNotifier,
                              builder: (context, seconds, _) {
                                final isUrgent = seconds <= 10;
                                final progress = (seconds / 45.0).clamp(0.0, 1.0);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isUrgent ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Actions Row with Fitted Text
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Stay on Page',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _redirectToMaintenance();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB71C1C),
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                      shadowColor: const Color(0xFFB71C1C).withValues(alpha: 0.3),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Proceed to Notice',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_rounded, size: 13),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 15,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account & Data Safe',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your profile, booking history, and payments remain safe.',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF166534),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsPausedCard() {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFEF3C7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.pause_circle_outline_rounded,
            size: 15,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookings & Payments Paused',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'New bookings and online payment submissions are paused.',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF92400E),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerMaintenanceNoticeBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF78350F),
              Color(0xFF92400E),
              Color(0xFFB45309),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF78350F).withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return ValueListenableBuilder<int>(
              valueListenable: _graceCountdownNotifier,
              builder: (context, seconds, _) {
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMobile
                            ? 'System update in progress • Bookings & payments paused'
                            : 'Dear Valued Customer: Scheduled system maintenance is in progress. Booking submissions & online payment processing are temporarily paused.',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 11, color: Color(0xFFFDE68A)),
                          const SizedBox(width: 3),
                          Text(
                            isMobile ? '${seconds}s' : '${seconds}s remaining',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFEF3C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _redirectToMaintenance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF92400E),
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        isMobile ? 'Details →' : 'View Details →',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
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

    if (_isGraceActive) {
      return Column(
        children: [
          _buildCustomerMaintenanceNoticeBanner(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.child,
            ),
          ),
        ],
      );
    }

    // ─── Scoped IT Support Lock Screen ───
    if (_activeItLockSession != null) {
      return _buildModuleLockedScreen(_activeItLockSession!);
    }

    // ─── Scoped IT Read-Only Notice Banner (Non-intrusive top bar) ───
    if (_activeItNoticeSession != null && !_itNoticeDismissed) {
      return Column(
        children: [
          _buildItNoticeBanner(_activeItNoticeSession!),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.child,
            ),
          ),
        ],
      );
    }

    return widget.child;
  }

  // ── Scoped IT Access Watchdog Helpers ──

  String _getModuleKeyForCurrentRoute(String userRole) {
    final roles = (widget.allowedRoles ?? []).map((r) => r.toLowerCase()).toList();
    final role = userRole.toLowerCase();

    // 1. Inventory & Storage (PagsanjanINV, inventory staff, storage room)
    if (roles.any((r) => r.contains('inv') || r.contains('pagsanjan') || r.contains('storage')) ||
        role.contains('inv') || role.contains('pagsanjan') || role.contains('storage')) {
      return 'inventory';
    }

    // 2. Kitchen & Chef Station (Chef, kitchen staff)
    if (roles.any((r) => r.contains('chef') || r.contains('kitchen')) ||
        role.contains('chef') || role.contains('kitchen')) {
      return 'chef';
    }

    // 3. Admin & Continuity Management
    if (roles.any((r) => r.contains('admin')) || role.contains('admin')) {
      return 'admin';
    }

    // 4. Staff POS Counter & Cashier
    if (roles.any((r) => r == 'staff' || r.contains('cashier') || r.contains('pos')) ||
        role == 'staff' || role.contains('cashier') || role.contains('pos')) {
      return 'staff';
    }

    // 5. Customer Portal & Online Reservations
    if (roles.any((r) => r.contains('customer') || r.contains('guest')) ||
        role.contains('customer') || role.contains('guest')) {
      return 'customer';
    }

    return 'customer';
  }

  Future<void> _checkItAccessStatus(String userRole) async {
    if (userRole == 'developer') return;
    try {
      final moduleKey = _getModuleKeyForCurrentRoute(userRole);
      final activeReq = await ItAccessService.getActiveRequestForModule(moduleKey);
      if (!mounted) return;
      if (activeReq != null) {
        final shouldLock = ItAccessService.shouldLockModule(activeReq);
        final currentReqId = activeReq['id']?.toString();
        setState(() {
          if (shouldLock) {
            _activeItLockSession = activeReq;
            _activeItNoticeSession = null;
          } else {
            _activeItLockSession = null;
            if (_lastItNoticeId != currentReqId) {
              _lastItNoticeId = currentReqId;
              _itNoticeDismissed = false;
            }
            _activeItNoticeSession = activeReq;
          }
        });
      } else {
        if (_activeItLockSession != null || _activeItNoticeSession != null) {
          setState(() {
            _activeItLockSession = null;
            _activeItNoticeSession = null;
            _lastItNoticeId = null;
            _itNoticeDismissed = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[AuthGuard] Error checking IT access status: $e');
    }
  }

  void _setupItAccessRealtime(String userRole) {
    if (userRole == 'developer') return;
    try {
      if (_itAccessRealtimeChannel != null) {
        Supabase.instance.client.removeChannel(_itAccessRealtimeChannel!);
      }
      final channelName = 'auth_guard_it_${userRole}_${DateTime.now().millisecondsSinceEpoch}';
      _itAccessRealtimeChannel = Supabase.instance.client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'it_access_requests',
            callback: (payload) {
              _checkItAccessStatus(userRole);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AuthGuard] Error setting up IT access realtime: $e');
    }
  }

  Widget _buildModuleLockedScreen(Map<String, dynamic> request) {
    final moduleKey = _getModuleKeyForCurrentRoute(_currentUserRole);
    String departmentTitle = 'Department Terminal';
    IconData departmentIcon = Icons.point_of_sale_rounded;
    Color accentColor = const Color(0xFFD97706);

    switch (moduleKey) {
      case 'chef':
        departmentTitle = 'Kitchen Station & Chef Display (ChefYCP)';
        departmentIcon = Icons.soup_kitchen_rounded;
        accentColor = const Color(0xFFEA580C);
        break;
      case 'inventory':
        departmentTitle = 'Storage & Inventory Management (PagsanjanINV)';
        departmentIcon = Icons.inventory_2_rounded;
        accentColor = const Color(0xFF059669);
        break;
      case 'staff':
        departmentTitle = 'Front-of-House Counter & POS Terminal';
        departmentIcon = Icons.point_of_sale_rounded;
        accentColor = const Color(0xFF2563EB);
        break;
      case 'customer':
        departmentTitle = 'Customer Portal & Reservation Services';
        departmentIcon = Icons.people_alt_rounded;
        accentColor = const Color(0xFF7C3AED);
        break;
      case 'admin':
        departmentTitle = 'Administrative Control Panel';
        departmentIcon = Icons.admin_panel_settings_rounded;
        accentColor = const Color(0xFFDC2626);
        break;
    }

    final ticketId = (request['id']?.toString() ?? 'ACTIVE').substring(0, 8).toUpperCase();
    final remainingTime = ItAccessService.getRemainingTimeString(request);
    final issueDesc = request['issue_description']?.toString() ?? 'Technical diagnostic in progress';
    final requestedBy = request['requested_by_name']?.toString() ?? 'Admin';

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 440;
    final isVerySmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 12 : 20,
            vertical: isSmall ? 20 : 32,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(isSmall ? 18 : 24),
              border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSmall ? 18 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Gradient Bar
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, const Color(0xFF38BDF8)],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(isSmall ? 16 : 28),
                    child: Column(
                      children: [
                        // Status Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 10 : 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  isSmall
                                      ? 'DEPARTMENT ON HOLD • IT ACTIVE'
                                      : 'DEPARTMENT ON HOLD • IT DIAGNOSTICS ACTIVE',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: isSmall ? 10 : 11,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                    letterSpacing: isSmall ? 0.3 : 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmall ? 16 : 20),

                        // Center Icon
                        Container(
                          width: isSmall ? 58 : 72,
                          height: isSmall ? 58 : 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 2),
                          ),
                          child: Icon(departmentIcon, color: accentColor, size: isSmall ? 28 : 36),
                        ),
                        SizedBox(height: isSmall ? 12 : 16),

                        // Title
                        Text(
                          departmentTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isSmall ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Our technical team is currently conducting authorized tests and system fixes on this terminal. Unaffected departments remain operational.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isSmall ? 12 : 13,
                            color: const Color(0xFF94A3B8),
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: isSmall ? 16 : 22),

                        // Diagnostic Session Info Card
                        Container(
                          padding: EdgeInsets.all(isSmall ? 12 : 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Ticket #$ticketId',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.firaCode(
                                        fontSize: isSmall ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFFDE68A)),
                                        const SizedBox(width: 4),
                                        Text(
                                          remainingTime,
                                          style: GoogleFonts.inter(
                                            fontSize: isSmall ? 10 : 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFEF3C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Color(0xFF1E293B), height: 18),
                              Text(
                                'Issue Reported by $requestedBy:',
                                style: GoogleFonts.inter(fontSize: isSmall ? 10.5 : 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                issueDesc,
                                style: GoogleFonts.inter(fontSize: isSmall ? 11.5 : 12.5, fontWeight: FontWeight.w500, color: const Color(0xFFE2E8F0)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmall ? 12 : 16),

                        // Reassurance Note
                        Container(
                          padding: EdgeInsets.all(isSmall ? 10 : 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF34D399)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Automatic Reopen & Test Isolation: All test orders placed during this session will be auto-purged and kitchen stock restored. This screen will automatically reopen as soon as the developer completes the session.',
                                  style: GoogleFonts.inter(
                                    fontSize: isSmall ? 10.5 : 11,
                                    color: const Color(0xFFA7F3D0),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmall ? 16 : 20),

                        // Refresh / Logout Action
                        if (isVerySmall) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _checkItAccessStatus(_currentUserRole),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Refresh Status'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Supabase.instance.client.auth.signOut();
                                _redirectToLogin();
                              },
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _checkItAccessStatus(_currentUserRole),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Refresh Status'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF475569)),
                                    padding: EdgeInsets.symmetric(vertical: isSmall ? 11 : 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await Supabase.instance.client.auth.signOut();
                                    _redirectToLogin();
                                  },
                                  icon: const Icon(Icons.logout_rounded, size: 16),
                                  label: const Text('Sign Out'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: isSmall ? 11 : 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItNoticeBanner(Map<String, dynamic> request) {
    final ticketId = (request['id']?.toString() ?? 'ACTIVE').substring(0, 8).toUpperCase();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Material(
      color: const Color(0xFF9A3412),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF9A3412),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFEA580C).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFDE68A), size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMobile
                      ? 'IT Diagnostic (#$ticketId) • Operations continue normally'
                      : 'IT Support Diagnostic Active (Ticket #$ticketId): Developer is reviewing this terminal in read-only mode. Transactions may proceed normally.',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'READ-ONLY',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFDE68A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    _itNoticeDismissed = true;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
