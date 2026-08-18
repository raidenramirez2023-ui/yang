import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Draggable modal properties
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _positionInitialized = false;

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

    if (isMobile) {
      return Positioned(
        bottom: 20,
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isClosed)
              Container(
                width: MediaQuery.of(context).size.width - 24,
                height: MediaQuery.of(context).size.height * 0.78,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
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
            _buildChatButton(totalUnread),
          ],
        ),
      );
    } else {
      // Desktop layout
      if (_isClosed) {
        return Positioned(
          bottom: 24,
          right: 24,
          child: _buildChatButton(totalUnread),
        );
      }

      final screenSize = MediaQuery.of(context).size;
      final modalWidth = _isMinimized ? 380.0 : 880.0;
      final maxModalHeight = screenSize.height - 100;
      final modalHeight =
          _isMinimized ? 52.0 : (maxModalHeight.clamp(500.0, 680.0));

      if (!_positionInitialized) {
        final safeInitialY =
            (screenSize.height - modalHeight - 60).clamp(40.0, 160.0);
        _position = Offset(
          screenSize.width - modalWidth - 30,
          safeInitialY,
        );
        _positionInitialized = true;
      }

      final maxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final maxY =
          (screenSize.height - modalHeight - 20).clamp(0.0, double.infinity);
      const minY = 40.0;
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
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 28,
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
                    _buildHeader(false, totalUnread),
                    if (!_isMinimized)
                      const Expanded(child: AdminChatPage()),
                  ],
                ),
              ),
            ),
          ),
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
              child: _buildChatButton(totalUnread),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildChatButton(int totalUnread) {
    return GestureDetector(
      onTap: () => setState(() => _isClosed = !_isClosed),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9A441), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14332E).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
      onPanStart: isMobile ? null : (_) => setState(() => _isDragging = true),
      onPanUpdate: isMobile
          ? null
          : (details) {
              setState(() {
                _position = Offset(
                  _position.dx + details.delta.dx,
                  _position.dy + details.delta.dy,
                );
              });
            },
      onPanEnd: isMobile ? null : (_) => setState(() => _isDragging = false),
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
              _isDragging
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
}
