import 'package:flutter/material.dart';
import 'package:yang_chow/pages/customer/customer_chat_page.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/chat_service.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context);

    if (isMobile) {
      return Positioned(
        bottom: 80, // Above bottom nav
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isClosed)
              Container(
                width: MediaQuery.of(context).size.width - 40,
                height: MediaQuery.of(context).size.height * 0.7,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      const CustomerChatPage(),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _isClosed = true),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildChatButton(),
          ],
        ),
      );
    } else {
      // Desktop Layout
      if (_isClosed) {
        return Positioned(
          bottom: 20,
          right: 20,
          child: _buildChatButton(),
        );
      }

      final screenSize = MediaQuery.of(context).size;
      final modalWidth = _isMinimized ? 300.0 : 400.0;
      final maxModalHeight = screenSize.height - 120;
      final modalHeight = _isMinimized ? 60.0 : (maxModalHeight.clamp(400.0, 600.0));

      if (!_positionInitialized) {
        final safeInitialY = (screenSize.height - modalHeight - 80).clamp(50.0, 200.0);
        _position = Offset(
          screenSize.width - modalWidth - 20,
          safeInitialY,
        );
        _positionInitialized = true;
      }

      final maxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final maxY = (screenSize.height - modalHeight - 40).clamp(0.0, double.infinity);
      final minY = 50.0;
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: _isDragging ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: _isDragging ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onPanStart: (details) => setState(() => _isDragging = true),
                      onPanUpdate: (details) {
                        setState(() {
                          _position = Offset(
                            _position.dx + details.delta.dx,
                            _position.dy + details.delta.dy,
                          );
                        });
                      },
                      onPanEnd: (details) => setState(() => _isDragging = false),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                        ),
                        child: Row(
                          children: [
                            if (_isDragging)
                              const Icon(Icons.drag_indicator, color: Colors.white, size: 16)
                            else
                              const Icon(Icons.support_agent, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Customer Support',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isMinimized = !_isMinimized),
                              child: Icon(
                                _isMinimized ? Icons.expand_more : Icons.minimize,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setState(() => _isClosed = true),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isMinimized)
                      const Expanded(
                        child: CustomerChatPage(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildChatButton() {
    return GestureDetector(
      onTap: () => setState(() => _isClosed = !_isClosed),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
