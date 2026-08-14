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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context);

    if (isMobile) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = screenSize.width - 40;
      final modalHeight = screenSize.height * 0.7;

      // Initialize position for mobile (button position)
      if (!_positionInitialized) {
        _position = Offset(
          screenSize.width - 80,
          screenSize.height - 150,
        );
        _positionInitialized = true;
      }

      // Constrain button position to screen bounds
      final maxX = (screenSize.width - 60).clamp(0.0, double.infinity);
      final maxY = (screenSize.height - 60).clamp(0.0, double.infinity);
      final minY = 50.0;
      final safeMaxY = maxY > minY ? maxY : minY;

      final constrainedPosition = Offset(
        _position.dx.clamp(0.0, maxX),
        _position.dy.clamp(minY, safeMaxY),
      );

      // Calculate modal position based on button position
      final modalPosition = Offset(
        constrainedPosition.dx,
        constrainedPosition.dy - modalHeight - 16,
      );

      // Constrain modal position
      final modalMaxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final modalMaxY = (screenSize.height - modalHeight - 80).clamp(0.0, double.infinity);
      final modalMinY = 50.0;
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                        ),
                        child: Row(
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
                              child: Icon(
                                _isDragging ? Icons.drag_indicator : Icons.drag_handle,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
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
                              onTap: () => setState(() => _isClosed = true),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
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
                decoration: BoxDecoration(
                  border: _isDragging 
                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                    : null,
                  shape: BoxShape.circle,
                ),
                child: _buildChatButton(),
              ),
            ),
          ),
        ],
      );
    } else {
      // Desktop Layout
      if (_isClosed) {
        final screenSize = MediaQuery.of(context).size;
        
        // Initialize position for closed state (chat button only)
        if (!_positionInitialized) {
          _position = Offset(
            screenSize.width - 100,
            screenSize.height - 100,
          );
          _positionInitialized = true;
        }

        // Constrain button position
        final maxX = (screenSize.width - 60).clamp(0.0, double.infinity);
        final maxY = (screenSize.height - 60).clamp(0.0, double.infinity);
        final minY = 50.0;
        final safeMaxY = maxY > minY ? maxY : minY;

        final constrainedPosition = Offset(
          _position.dx.clamp(0.0, maxX),
          _position.dy.clamp(minY, safeMaxY),
        );

        return Positioned(
          left: constrainedPosition.dx,
          top: constrainedPosition.dy,
          child: GestureDetector(
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
              decoration: BoxDecoration(
                border: _isDragging 
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
                shape: BoxShape.circle,
              ),
              child: _buildChatButton(),
            ),
          ),
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
                    color: Colors.black.withValues(alpha: 0.3),
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
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                      ),
                      child: Row(
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
                            child: Icon(
                              _isDragging ? Icons.drag_indicator : Icons.drag_handle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
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
                    if (!_isMinimized)
                      const Expanded(
                        child: CustomerChatPage(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Draggable chat button when modal is open
          Positioned(
            left: constrainedPosition.dx + modalWidth - 60,
            top: constrainedPosition.dy + modalHeight + 16,
            child: GestureDetector(
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
                decoration: BoxDecoration(
                  border: _isDragging 
                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                    : null,
                  shape: BoxShape.circle,
                ),
                child: _buildChatButton(),
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
              color: Colors.black.withValues(alpha: 0.3),
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
            if (_isDragging)
              const Positioned(
                bottom: 2,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.white70,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
