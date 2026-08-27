import 'dart:async';
import 'package:flutter/material.dart';

/// Overlay-based global messenger that survives route transitions,
/// unmounted scaffolds, and prevents "deactivated widget's ancestor is unsafe" errors.
class GlobalMessenger {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showSuccess(String message) {
    _showToast(
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF15803D), // Emerald green
      borderColor: const Color(0xFF86EFAC),
      textColor: Colors.white,
    );
  }

  static void showError(String message) {
    _showToast(
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFFB91C1C), // Crimson red
      borderColor: const Color(0xFFFCA5A5),
      textColor: Colors.white,
    );
  }

  static void showWarning(String message) {
    _showToast(
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFC2410C), // Amber orange
      borderColor: const Color(0xFFFDBA74),
      textColor: Colors.white,
    );
  }

  static void _showToast({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay == null) return;

      _dismissTimer?.cancel();
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => _GlobalToastWidget(
          message: message,
          icon: icon,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          textColor: textColor,
          onDismiss: () {
            if (_currentEntry == entry) {
              try {
                _currentEntry?.remove();
              } catch (_) {}
              _currentEntry = null;
            }
          },
        ),
      );

      _currentEntry = entry;
      overlay.insert(entry);

      _dismissTimer = Timer(duration, () {
        if (_currentEntry == entry) {
          try {
            _currentEntry?.remove();
          } catch (_) {}
          _currentEntry = null;
        }
      });
    });
  }
}

class _GlobalToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _GlobalToastWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_GlobalToastWidget> createState() => _GlobalToastWidgetState();
}

class _GlobalToastWidgetState extends State<_GlobalToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.borderColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.backgroundColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
