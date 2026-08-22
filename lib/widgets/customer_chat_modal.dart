import 'package:flutter/material.dart';
import 'package:yang_chow/pages/customer/customer_chat_page.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerChatModal extends StatefulWidget {
  const CustomerChatModal({super.key});

  @override
  State<CustomerChatModal> createState() => _CustomerChatModalState();
}

class _CustomerChatModalState extends State<CustomerChatModal> {
  bool _isClosed = true;
  bool _isMinimized = false;

  // Draggable modal properties
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _positionInitialized = false;

  int _unreadCount = 0;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _initUnreadStream();
  }

  void _initUnreadStream() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', currentUser.email!)
        .order('created_at', ascending: true);

    _messagesStream?.listen((messages) {
      if (mounted) {
        final unread = messages.where(
          (msg) => msg['is_from_customer'] == false && msg['is_read'] == false,
        ).length;
        setState(() {
          _unreadCount = unread;
        });
      }
    }, onError: (e) {
      debugPrint('Error in chat unread stream: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        !ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context);

    if (isMobile) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = screenSize.width - 24;
      final modalHeight = (screenSize.height * 0.78).clamp(380.0, 680.0);

      // Initialize position for mobile (button position)
      if (!_positionInitialized) {
        _position = Offset(
          screenSize.width - 76,
          screenSize.height - 120,
        );
        _positionInitialized = true;
      }

      final maxX = (screenSize.width - 60).clamp(0.0, double.infinity);
      final maxY = (screenSize.height - 60).clamp(0.0, double.infinity);
      const minY = 50.0;
      final safeMaxY = maxY > minY ? maxY : minY;

      final constrainedPosition = Offset(
        _position.dx.clamp(0.0, maxX),
        _position.dy.clamp(minY, safeMaxY),
      );

      final modalPosition = Offset(
        12,
        constrainedPosition.dy - modalHeight - 16,
      );

      final modalMaxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final modalMaxY =
          (screenSize.height - modalHeight - 80).clamp(0.0, double.infinity);
      const modalMinY = 50.0;
      final modalSafeMaxY = modalMaxY > modalMinY ? modalMaxY : modalMinY;

      final constrainedModalPosition = Offset(
        modalPosition.dx.clamp(0.0, modalMaxX),
        modalPosition.dy.clamp(modalMinY, modalSafeMaxY),
      );

      return Stack(
        children: [
          if (!_isClosed)
            Positioned(
              left: constrainedModalPosition.dx,
              top: constrainedModalPosition.dy,
              child: Container(
                width: modalWidth,
                height: modalHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: _isDragging
                        ? const Color(0xFF14332E)
                        : const Color(0xFFE2E8F0),
                    width: _isDragging ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Top draggable bar
                      _buildModalHeaderBar(isMobile: true),
                      const Expanded(
                        child: CustomerChatPage(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: constrainedPosition.dx,
            top: constrainedPosition.dy,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    _position.dx + details.delta.dx,
                    _position.dy + details.delta.dy,
                  );
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              child: _buildChatButton(),
            ),
          ),
        ],
      );
    } else {
      // Desktop Layout
      if (_isClosed) {
        final screenSize = MediaQuery.of(context).size;

        if (!_positionInitialized) {
          _position = Offset(
            screenSize.width - 86,
            screenSize.height - 96,
          );
          _positionInitialized = true;
        }

        final maxX = (screenSize.width - 64).clamp(0.0, double.infinity);
        final maxY = (screenSize.height - 64).clamp(0.0, double.infinity);
        const minY = 50.0;
        final safeMaxY = maxY > minY ? maxY : minY;

        final constrainedPosition = Offset(
          _position.dx.clamp(0.0, maxX),
          _position.dy.clamp(minY, safeMaxY),
        );

        return Positioned(
          left: constrainedPosition.dx,
          top: constrainedPosition.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position.dx + details.delta.dx,
                  _position.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (_) => setState(() => _isDragging = false),
            child: _buildChatButton(),
          ),
        );
      }

      final screenSize = MediaQuery.of(context).size;
      final modalWidth = _isMinimized ? 320.0 : 420.0;
      final maxModalHeight = screenSize.height - 100;
      final modalHeight =
          _isMinimized ? 52.0 : (maxModalHeight.clamp(440.0, 620.0));

      if (!_positionInitialized) {
        final safeInitialY =
            (screenSize.height - modalHeight - 80).clamp(50.0, 200.0);
        _position = Offset(
          screenSize.width - modalWidth - 24,
          safeInitialY,
        );
        _positionInitialized = true;
      }

      final maxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final maxY =
          (screenSize.height - modalHeight - 30).clamp(0.0, double.infinity);
      const minY = 50.0;
      final safeMaxY = maxY > minY ? maxY : minY;

      final constrainedPosition = Offset(
        _position.dx.clamp(0.0, maxX),
        _position.dy.clamp(minY, safeMaxY),
      );

      return Stack(
        children: [
          Positioned(
            left: constrainedPosition.dx,
            top: constrainedPosition.dy,
            child: Container(
              width: modalWidth,
              height: modalHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: _isDragging
                      ? const Color(0xFF14332E)
                      : const Color(0xFFE2E8F0),
                  width: _isDragging ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _buildModalHeaderBar(isMobile: false),
                    if (!_isMinimized)
                      const Expanded(
                        child: CustomerChatPage(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Floating chat button to toggle when desktop open
          Positioned(
            left: constrainedPosition.dx + modalWidth - 58,
            top: constrainedPosition.dy + modalHeight + 14,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    _position.dx + details.delta.dx,
                    _position.dy + details.delta.dy,
                  );
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              child: _buildChatButton(),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildModalHeaderBar({required bool isMobile}) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDragging = true),
      onPanUpdate: (details) {
        setState(() {
          _position = Offset(
            _position.dx + details.delta.dx,
            _position.dy + details.delta.dy,
          );
        });
      },
      onPanEnd: (_) => setState(() => _isDragging = false),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isDragging
                  ? Icons.drag_indicator_rounded
                  : Icons.drag_handle_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Yang Chow Support',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (!isMobile) ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isMinimized
                      ? Icons.open_in_full_rounded
                      : Icons.remove_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 18,
                ),
                onPressed: () => setState(() => _isMinimized = !_isMinimized),
              ),
              const SizedBox(width: 12),
            ],
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.85),
                size: 20,
              ),
              onPressed: () => setState(() => _isClosed = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return GestureDetector(
      onTap: () => setState(() => _isClosed = !_isClosed),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDE68A), Color(0xFFD9A441), Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD9A441).withOpacity(0.55),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _isClosed
                  ? Icons.chat_bubble_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF0F2622),
              size: _isClosed ? 26 : 32,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
