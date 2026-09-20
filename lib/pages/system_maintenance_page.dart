import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_settings_service.dart';

class SystemMaintenancePage extends StatefulWidget {
  const SystemMaintenancePage({super.key});

  @override
  State<SystemMaintenancePage> createState() => _SystemMaintenancePageState();
}

class _SystemMaintenancePageState extends State<SystemMaintenancePage>
    with TickerProviderStateMixin {
  final AppSettingsService _settings = AppSettingsService();
  bool _isChecking = false;
  String _reason = 'Scheduled System Maintenance';
  String _message =
      'YCPRMS is temporarily undergoing scheduled maintenance. Please check back shortly.';
  DateTime? _startTime;
  DateTime? _endTime;
  String _returnRoute = '/login';
  bool _isNoticeExpanded = false;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _countdownTimer;
  Timer? _autoPollTimer;
  Duration _remaining = Duration.zero;
  bool _isAutoChecking = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _loadMaintenanceDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['returnRoute'] != null) {
      _returnRoute = args['returnRoute'] as String;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endTime == null) return;
      final now = DateTime.now();
      final diff = _endTime!.toLocal().difference(now);
      if (diff.isNegative || diff == Duration.zero) {
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {
            _remaining = Duration.zero;
          });
          _onCountdownCompleted();
        }
      } else {
        if (mounted) {
          setState(() {
            _remaining = diff;
          });
        }
      }
    });
  }

  Future<void> _onCountdownCompleted() async {
    if (!mounted || _isAutoChecking) return;
    setState(() => _isAutoChecking = true);

    final isStillActive = await AppSettingsService.checkMaintenanceModeFromDB();

    if (!mounted) return;

    if (!isStillActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF064E3B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF10B981)),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Maintenance completed! Redirecting to login...',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(_returnRoute);
      }
      return;
    }

    setState(() => _isAutoChecking = false);
    _startAutoPolling();
  }

  void _startAutoPolling() {
    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      final isStillActive = await AppSettingsService.checkMaintenanceModeFromDB();
      if (!mounted) return;
      if (!isStillActive) {
        _autoPollTimer?.cancel();
        Navigator.of(context).pushReplacementNamed(_returnRoute);
      }
    });
  }

  Future<void> _loadMaintenanceDetails() async {
    await _settings.refreshSettings();
    if (mounted) {
      final isStillActive = _settings.isMaintenanceModeEnabled();
      if (!isStillActive) {
        Navigator.of(context).pushReplacementNamed(_returnRoute);
        return;
      }

      final startStr = _settings.getMaintenanceStartTime();
      final endStr = _settings.getMaintenanceEndTime();
      setState(() {
        _reason = _settings.getMaintenanceReason();
        _message = _settings.getMaintenanceMessage();
        _startTime = (startStr != null && startStr.isNotEmpty) ? DateTime.tryParse(startStr) : null;
        _endTime = (endStr != null && endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
        if (_endTime != null) {
          final now = DateTime.now();
          final diff = _endTime!.toLocal().difference(now);
          if (diff.isNegative || diff == Duration.zero) {
            _remaining = Duration.zero;
          } else {
            _remaining = diff;
          }
        }
      });
      if (_endTime != null) {
        if (_remaining == Duration.zero) {
          _onCountdownCompleted();
        } else {
          _startCountdown();
        }
      }
    }
  }

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    await _settings.refreshSettings();
    final isStillActive = await AppSettingsService.checkMaintenanceModeFromDB();

    if (mounted) {
      setState(() => _isChecking = false);
      if (!isStillActive) {
        Navigator.of(context).pushReplacementNamed(_returnRoute);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFF59E0B)),
            ),
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24), size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Maintenance operations are currently ongoing. Please try again shortly.',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    _countdownTimer?.cancel();
    _autoPollTimer?.cancel();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  double get _calculatedProgress {
    if (_endTime == null) return 0.75;
    if (_remaining == Duration.zero) return 1.0;

    // Use actual database startTime if available, otherwise assume 2-hour default window before endTime
    final effectiveStartTime = _startTime ?? _endTime!.subtract(const Duration(hours: 2));
    final totalSeconds = _endTime!.difference(effectiveStartTime).inSeconds;

    if (totalSeconds > 0) {
      final elapsedSeconds = totalSeconds - _remaining.inSeconds;
      final pct = elapsedSeconds / totalSeconds;
      return pct.clamp(0.05, 0.99);
    }

    return 0.75;
  }

  String get _publicFriendlyReason {
    final lower = _reason.toLowerCase();
    if (lower.contains('migration') ||
        lower.contains('index') ||
        lower.contains('database') ||
        lower.contains('patch') ||
        lower.contains('cold storage') ||
        lower.contains('infrastructure') ||
        lower.contains('remediation')) {
      return 'Scheduled System Upgrade & Enhancements';
    }
    return _reason.trim().isEmpty ? 'Scheduled System Upgrade & Enhancements' : _reason.trim();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final hasCountdown = _endTime != null && _remaining > Duration.zero;
    final days = _remaining.inDays;
    final hours = _twoDigits(days > 0 ? _remaining.inHours.remainder(24) : _remaining.inHours);
    final minutes = _twoDigits(_remaining.inMinutes.remainder(60));
    final seconds = _twoDigits(_remaining.inSeconds.remainder(60));

    final progressValue = _calculatedProgress;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // Elegant Enterprise Ambient Matrix Background
          Positioned.fill(child: CustomPaint(painter: _EnterpriseMatrixPainter())),

          // Top Ambient Lighting Halo
          Positioned(
            top: -160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 580,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.09),
                      const Color(0xFF0F172A).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Responsive Content Box
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 20 : 36,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary Enterprise Card
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF1E293B),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.03),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isSmallScreen ? 20 : 28,
                              isSmallScreen ? 28 : 34,
                              isSmallScreen ? 20 : 28,
                              isSmallScreen ? 24 : 30,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // System Status Header Badge
                                // Unified Enterprise Status Chip: [ YCPRMS | ● SYSTEM MAINTENANCE ]
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131D2E).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFF24344D),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Brand Monogram
                                      Text(
                                        'YCPRMS',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),

                                      // Sleek Vertical Divider
                                      Container(
                                        height: 10,
                                        width: 1,
                                        margin: const EdgeInsets.symmetric(horizontal: 9),
                                        color: const Color(0xFF334155),
                                      ),

                                      // Live Pulsing Amber Dot
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFF59E0B),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFFF59E0B),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 6),

                                      // Status Text
                                      Text(
                                        'SCHEDULED DOWNTIME',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                          color: const Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Refined System Status Glyph
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                          const Color(0xFF1E293B).withValues(alpha: 0.4),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.build_circle_outlined,
                                        size: 38,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Authoritative Headline
                                Text(
                                  'System Under Maintenance',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 22 : 25,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Operational Scope Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131D2F),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF334155).withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shield_outlined,
                                        size: 14,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          _publicFriendlyReason,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Administrator Bulletin / Incident Callout Card (Enterprise Redesign)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0F1A2C),
                                        Color(0xFF0A111F),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF1E2E48),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        // Amber Left Accent Indicator Bar
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: 4,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Color(0xFFF59E0B),
                                                  Color(0xFFD97706),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Watermark Quote Icon in background
                                        Positioned(
                                          top: 6,
                                          right: 8,
                                          child: Icon(
                                            Icons.format_quote_rounded,
                                            size: 44,
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                                          ),
                                        ),

                                        // Main Content with padding
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            isSmallScreen ? 14 : 18,
                                            isSmallScreen ? 12 : 14,
                                            isSmallScreen ? 12 : 16,
                                            isSmallScreen ? 12 : 14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Top Header Row with responsive Wrap
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          decoration: const BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Color(0xFFF59E0B),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'OFFICIAL ADVISORY',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            letterSpacing: 0.8,
                                                            color: const Color(0xFFFBBF24),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 10),

                                              // Notice Message Content with Smart Expand/Collapse
                                              Builder(
                                                builder: (context) {
                                                  final trimmedMessage = _message.trim();
                                                  final isLongNotice = trimmedMessage.length > 140 || trimmedMessage.contains('\n');

                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      AnimatedCrossFade(
                                                        duration: const Duration(milliseconds: 260),
                                                        crossFadeState: _isNoticeExpanded || !isLongNotice
                                                            ? CrossFadeState.showSecond
                                                            : CrossFadeState.showFirst,
                                                        firstChild: Text(
                                                          trimmedMessage,
                                                          maxLines: 3,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.inter(
                                                            fontSize: isSmallScreen ? 12.5 : 13,
                                                            height: 1.6,
                                                            letterSpacing: 0.2,
                                                            color: const Color(0xFFE2E8F0),
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                        ),
                                                        secondChild: Text(
                                                          trimmedMessage,
                                                          style: GoogleFonts.inter(
                                                            fontSize: isSmallScreen ? 12.5 : 13,
                                                            height: 1.6,
                                                            letterSpacing: 0.2,
                                                            color: const Color(0xFFE2E8F0),
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isLongNotice) ...[
                                                        const SizedBox(height: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              _isNoticeExpanded = !_isNoticeExpanded;
                                                            });
                                                          },
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  _isNoticeExpanded ? 'Show less' : 'Read full advisory',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: const Color(0xFFFBBF24),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Icon(
                                                                  _isNoticeExpanded
                                                                      ? Icons.keyboard_arrow_up_rounded
                                                                      : Icons.keyboard_arrow_down_rounded,
                                                                  size: 15,
                                                                  color: const Color(0xFFFBBF24),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // Realistic Technical Progress Indicator (Synchronized with Countdown Timer)
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.05, end: progressValue),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedValue, _) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _isAutoChecking
                                                        ? const Color(0xFF38BDF8)
                                                        : const Color(0xFFF59E0B),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _isAutoChecking
                                                      ? 'Final system verification in progress…'
                                                      : 'Operational progress',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${(animatedValue * 100).toInt()}%',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFFBBF24),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            height: 5,
                                            width: double.infinity,
                                            color: const Color(0xFF1E293B),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: FractionallySizedBox(
                                                widthFactor: animatedValue.clamp(0.01, 1.0),
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Color(0xFFD97706),
                                                        Color(0xFFF59E0B),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Enterprise Countdown Console Card
                        if (_endTime != null)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF1E293B),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Target Completion Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF334155).withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                        color: Color(0xFFFBBF24),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ESTIMATED RESTORATION',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF94A3B8),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('EEE, MMM d • h:mm a').format(_endTime!.toLocal()),
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF131D2F),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'TARGET',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFBBF24),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Timer Units or Time-Reached Status
                                if (hasCountdown) ...[
                                  Row(
                                    children: [
                                      if (days > 0) ...[
                                        Expanded(child: _CountdownUnit(value: _twoDigits(days), label: 'DAYS')),
                                        const _CountdownSep(),
                                      ],
                                      Expanded(child: _CountdownUnit(value: hours, label: 'HOURS')),
                                      const _CountdownSep(),
                                      Expanded(child: _CountdownUnit(value: minutes, label: 'MINUTES')),
                                      const _CountdownSep(),
                                      Expanded(child: _CountdownUnit(value: seconds, label: 'SECONDS')),
                                    ],
                                  ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131D2F),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            'Estimated time reached. Checking if system is ready…',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFFBBF24),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Action Controls
                        // 1. Primary Action: Check Status
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFF334155),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            onPressed: _isChecking ? null : _checkAgain,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: Color(0xFFFBBF24),
                                  ),
                            label: Text(
                              _isChecking ? 'Checking status…' : 'Check if Maintenance is Done',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 2. Secondary Action: Back to Login
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await Supabase.instance.client.auth.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushReplacementNamed(_returnRoute);
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: Text(
                              'Back to Login',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Live Polling & Security Assurance Badges (Fully Responsive)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Auto-reconnect sync active',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '•',
                              style: TextStyle(color: const Color(0xFF475569)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Data safely preserved',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'We apologize for any temporary inconvenience.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
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
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmall ? 8 : 10,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1322),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isSmall ? 20 : 23,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFBBF24),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownSep extends StatelessWidget {
  const _CountdownSep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _EnterpriseMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const dotRadius = 0.9;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EnterpriseMatrixPainter old) => false;
}
