import 'package:flutter/material.dart';
import '../pages/admin/admin_chat_page.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_utils.dart';

class AdminChatModal extends StatefulWidget {
  const AdminChatModal({super.key});

  @override
  State<AdminChatModal> createState() => _AdminChatModalState();
}

class _AdminChatModalState extends State<AdminChatModal> {
  final ChatService _chatService = ChatService();
  Stream<List<Map<String, dynamic>>>? _conversationsStream;
  List<Map<String, dynamic>> _conversations = [];

  bool _isMinimized = false;
  bool _isClosed = true;

  // Draggable floating bubble position
  Offset _buttonPosition = const Offset(0, 0);
  bool _isDraggingButton = false;
  bool _buttonPositionInitialized = false;

  // Draggable modal window position (for desktop)
  Offset _modalPosition = const Offset(0, 0);
  bool _isDraggingModal = false;
  bool _modalPositionInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _conversationsStream = _chatService.getConversationsStream();
    _conversationsStream?.listen((conversations) {
      if (mounted) {
        setState(() {
          _conversations = conversations;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        !ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context);

    return _buildFloatingChatButton(isMobile);
  }

  Widget _buildFloatingChatButton(bool isMobile) {
    final totalUnread = _conversations.fold<int>(
      0,
      (sum, conv) =>
          sum + ((conv['unread_customer_count'] as num?)?.toInt() ?? 0),
    );

    final screenSize = MediaQuery.of(context).size;

    // Initialize button position (bottom right)
    if (!_buttonPositionInitialized) {
      _buttonPosition = Offset(
        (screenSize.width - 80).clamp(10.0, double.infinity),
        (screenSize.height - (isMobile ? 130 : 86)).clamp(50.0, double.infinity),
      );
      _buttonPositionInitialized = true;
    }

    final btnMaxX = (screenSize.width - 68).clamp(0.0, double.infinity);
    final btnMaxY = (screenSize.height - 68).clamp(0.0, double.infinity);
    const btnMinY = 50.0;
    const btnMinX = 10.0;
    final btnSafeMaxY = btnMaxY > btnMinY ? btnMaxY : btnMinY;

    final constrainedBtnPosition = Offset(
      _buttonPosition.dx.clamp(btnMinX, btnMaxX),
      _buttonPosition.dy.clamp(btnMinY, btnSafeMaxY),
    );

    // 1. CLOSED STATE: Draggable floating chat bubble
    if (_isClosed) {
      return Positioned(
        left: constrainedBtnPosition.dx,
        top: constrainedBtnPosition.dy,
        child: GestureDetector(
          onPanStart: (_) => setState(() => _isDraggingButton = true),
          onPanUpdate: (details) {
            setState(() {
              _buttonPosition = Offset(
                _buttonPosition.dx + details.delta.dx,
                _buttonPosition.dy + details.delta.dy,
              );
            });
          },
          onPanEnd: (_) => setState(() => _isDraggingButton = false),
          onTap: () => setState(() => _isClosed = false),
          child: _buildChatButton(totalUnread),
        ),
      );
    }

    // 2. OPEN STATE: Mobile Layout
    if (isMobile) {
      final modalWidth = screenSize.width - 24;
      final modalHeight = (screenSize.height * 0.78).clamp(380.0, 680.0);
      const modalLeft = 12.0;
      final modalTop = (screenSize.height - modalHeight - 75).clamp(40.0, double.infinity);

      return Stack(
        children: [
          Positioned(
            left: modalLeft,
            top: modalTop,
            child: Container(
              width: modalWidth,
              height: modalHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    _buildHeader(true, totalUnread),
                    const Expanded(child: AdminChatPage()),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: constrainedBtnPosition.dx,
            top: constrainedBtnPosition.dy,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDraggingButton = true),
              onPanUpdate: (details) {
                setState(() {
                  _buttonPosition = Offset(
                    _buttonPosition.dx + details.delta.dx,
                    _buttonPosition.dy + details.delta.dy,
                  );
                });
              },
              onPanEnd: (_) => setState(() => _isDraggingButton = false),
              onTap: () => setState(() => _isClosed = true),
              child: _buildChatButton(totalUnread),
            ),
          ),
        ],
      );
    }

    // 3. OPEN STATE: Desktop Layout
    final modalWidth = _isMinimized ? 380.0 : 880.0;
    final maxModalHeight = screenSize.height - 100;
    final modalHeight =
        _isMinimized ? 52.0 : (maxModalHeight.clamp(500.0, 680.0));

    if (!_modalPositionInitialized) {
      final safeInitialY =
          (screenSize.height - modalHeight - 60).clamp(40.0, 160.0);
      _modalPosition = Offset(
        (screenSize.width - modalWidth - 30).clamp(10.0, double.infinity),
        safeInitialY,
      );
      _modalPositionInitialized = true;
    }

    final modalMaxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
    final modalMaxY =
        (screenSize.height - modalHeight - 20).clamp(0.0, double.infinity);
    const modalMinY = 40.0;
    final modalSafeMaxY = modalMaxY > modalMinY ? modalMaxY : modalMinY;

    final constrainedModalPosition = Offset(
      _modalPosition.dx.clamp(0.0, modalMaxX),
      _modalPosition.dy.clamp(modalMinY, modalSafeMaxY),
    );

    return Stack(
      children: [
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
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: _isDraggingModal
                    ? const Color(0xFF14332E)
                    : const Color(0xFFE2E8F0),
                width: _isDraggingModal ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _buildHeader(false, totalUnread),
                  if (!_isMinimized)
                    const Expanded(child: AdminChatPage()),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: constrainedBtnPosition.dx,
          top: constrainedBtnPosition.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDraggingButton = true),
            onPanUpdate: (details) {
              setState(() {
                _buttonPosition = Offset(
                  _buttonPosition.dx + details.delta.dx,
                  _buttonPosition.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (_) => setState(() => _isDraggingButton = false),
            onTap: () => setState(() => _isClosed = true),
            child: _buildChatButton(totalUnread),
          ),
        ),
      ],
    );
  }

  Widget _buildChatButton(int totalUnread) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isDraggingButton ? const Color(0xFFF59E0B) : const Color(0xFFD9A441),
            width: _isDraggingButton ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14332E).withValues(alpha: _isDraggingButton ? 0.5 : 0.35),
              blurRadius: _isDraggingButton ? 20 : 16,
              offset: Offset(0, _isDraggingButton ? 8 : 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _isClosed ? Icons.forum_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: _isClosed ? 26 : 32,
            ),
            if (totalUnread > 0)
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
                        color: Colors.black.withValues(alpha: 0.2),
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
                      totalUnread > 99 ? '99+' : '$totalUnread',
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

  Widget _buildHeader(bool isMobile, int totalUnread) {
    return GestureDetector(
      onPanStart: isMobile ? null : (_) => setState(() => _isDraggingModal = true),
      onPanUpdate: isMobile
          ? null
          : (details) {
              setState(() {
                _modalPosition = Offset(
                  _modalPosition.dx + details.delta.dx,
                  _modalPosition.dy + details.delta.dy,
                );
              });
            },
      onPanEnd: isMobile ? null : (_) => setState(() => _isDraggingModal = false),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
              _isDraggingModal
                  ? Icons.drag_indicator_rounded
                  : Icons.support_agent_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Customer Support Console',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (totalUnread > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalUnread new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (!isMobile) ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isMinimized
                      ? Icons.open_in_full_rounded
                      : Icons.remove_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
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
                color: Colors.white.withValues(alpha: 0.85),
                size: 20,
              ),
              onPressed: () => setState(() => _isClosed = true),
            ),
          ],
        ),
      ),
    );
  }
}
