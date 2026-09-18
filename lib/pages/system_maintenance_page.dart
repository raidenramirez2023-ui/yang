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
  DateTime? _endTime;
  String _returnRoute = '/login';

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
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
      if (mounted) {
        setState(() {
          _remaining = diff.isNegative ? Duration.zero : diff;
        });
      }
    });
  }

  Future<void> _loadMaintenanceDetails() async {
    await _settings.refreshSettings();
    if (mounted) {
      final isStillActive = _settings.isMaintenanceModeEnabled();
      if (!isStillActive) {
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      final endStr = _settings.getMaintenanceEndTime();
      setState(() {
        _reason = _settings.getMaintenanceReason();
        _message = _settings.getMaintenanceMessage();
        _endTime =
            (endStr != null && endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
        if (_endTime != null) {
          final now = DateTime.now();
          final diff = _endTime!.toLocal().difference(now);
          _remaining = diff.isNegative ? Duration.zero : diff;
        }
      });
      if (_endTime != null) _startCountdown();
    }
  }

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    await _settings.refreshSettings();
    final isStillActive = _settings.isMaintenanceModeEnabled();

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
              side: const BorderSide(color: Color(0xFFB71C1C)),
            ),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Maintenance is still in progress. Please check again shortly.',
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
    _progressController.dispose();
    _fadeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hasCountdown = _endTime != null && _remaining > Duration.zero;
    final hours = _twoDigits(_remaining.inHours);
    final minutes = _twoDigits(_remaining.inMinutes.remainder(60));
    final seconds = _twoDigits(_remaining.inSeconds.remainder(60));

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB71C1C).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Top Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: const Color(0xFFB71C1C).withValues(alpha: 0.06),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                      const Color(0xFFF59E0B).withValues(alpha: 0.05),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.engineering_rounded, size: 44, color: Color(0xFFF59E0B)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  const Color(0xFFB71C1C).withValues(alpha: 0.3),
                                  const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFB71C1C).withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                'YCPRMS',
                                style: GoogleFonts.cinzel(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  color: const Color(0xFFFF8A80),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'System Under\nMaintenance',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFBBF24)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _reason,
                                      textAlign: TextAlign.center,
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
                            const SizedBox(height: 16),
                            Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, height: 1.65, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 22),
                            AnimatedBuilder(
                              animation: _progressController,
                              builder: (_, __) => ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 3,
                                  width: double.infinity,
                                  color: const Color(0xFF1E293B),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _progressController.value,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedBuilder(
                              animation: _progressController,
                              builder: (_, __) => Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Maintenance in progress',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF475569))),
                                  Text('${(_progressController.value * 100).toInt()}%',
                                      style: GoogleFonts.inter(
                                          fontSize: 10, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Countdown Card
                      if (_endTime != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF38BDF8)),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Estimated Completion',
                                            style: GoogleFonts.inter(
                                                fontSize: 10, color: const Color(0xFF475569), letterSpacing: 0.5)),
                                        Text(
                                          DateFormat('EEE, MMM d • h:mm a').format(_endTime!.toLocal()),
                                          style: GoogleFonts.inter(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (hasCountdown) ...[
                                const SizedBox(height: 16),
                                const Divider(color: Color(0xFF1E293B), height: 1),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Row(
                                      children: [
                                        Expanded(child: _CountdownUnit(value: hours, label: 'HRS')),
                                        _CountdownSep(),
                                        Expanded(child: _CountdownUnit(value: minutes, label: 'MIN')),
                                        _CountdownSep(),
                                        Expanded(child: _CountdownUnit(value: seconds, label: 'SEC')),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),


                      const SizedBox(height: 16),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacementNamed(_returnRoute);
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text('Back to Login',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFF1E293B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isChecking ? null : _checkAgain,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF64748B)),
                                )
                              : const Icon(Icons.refresh_rounded, size: 17),
                          label: Text(
                            _isChecking ? 'Checking…' : 'Check if Maintenance is Done',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('We apologize for the inconvenience.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
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
    final fontSize = screenWidth < 360 ? 20.0 : 26.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF38BDF8),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: const Color(0xFF475569),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CountdownSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 360 ? 4.0 : 8.0;
    return Padding(
      padding: EdgeInsets.only(bottom: 20, left: hPad, right: hPad),
      child: Text(
        ':',
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E3A5F),
        ),
      ),
    );
  }
}



class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
