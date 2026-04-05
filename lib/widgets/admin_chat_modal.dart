import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Stream<List<Map<String, dynamic>>>? _conversationsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  Map<String, dynamic>? _selectedConversation;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isMinimized = false;
  bool _isClosed = false;

  // Draggable modal properties
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _positionInitialized = false;

  // Mobile-specific properties

  @override
  void initState() {
    super.initState();
    // Auto-close on all devices
    _isClosed = true;
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    // Set up stream for conversations and listen for updates
    _conversationsStream = _chatService.getConversationsStream();
    
    // Listen to stream updates in real-time
    _conversationsStream?.listen((conversations) {
      if (mounted) {
        setState(() {
          _conversations = conversations;
        });
      }
    });
    
    setState(() => _isLoading = false);
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
    });

    final customerEmail = conversation['customer_email'];
    
    // Set up stream for messages in this conversation
    _messagesStream = _chatService.getMessagesStream(customerEmail);

    // Mark messages as read using the database function
    _markMessagesAsReadInDatabase(customerEmail);
  }

  Future<void> _markMessagesAsReadInDatabase(String customerEmail) async {
    try {
      // Call the function and get the new unread count
      final newCount = await Supabase.instance.client.rpc('mark_conversation_as_read', params: {
        'p_customer_email': customerEmail,
      });
      
      // Update the local conversations list to trigger immediate UI update
      setState(() {
        if (_selectedConversation != null) {
          // Update the selected conversation's unread count
          _selectedConversation!['unread_customer_count'] = newCount;
        }
        
        // Update the conversations list
        _conversations = _conversations.map((conv) {
          if (conv['customer_email'] == customerEmail) {
            conv['unread_customer_count'] = newCount;
          }
          return conv;
        }).toList();
      });
      
      print('Messages marked as read, new count: $newCount');
    } catch (e) {
      print('Error marking conversation as read in database: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || 
        _isSending || 
        _selectedConversation == null) {
      return;
    }

    final customerEmail = _selectedConversation!['customer_email'];
    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';

    setState(() => _isSending = true);

    try {
      await _chatService.sendAdminMessage(
        customerEmail: customerEmail,
        customerName: customerName,
        message: _messageController.text.trim(),
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context);
    
    // Show floating chat button on all devices
    return _buildFloatingChatButton(isMobile);
  }

  Widget _buildFloatingChatButton(bool isMobile) {
    final totalUnread = _conversations.fold<int>(
      0, (sum, conv) => sum + ((conv['unread_customer_count'] as num?)?.toInt() ?? 0)
    );

    if (isMobile) {
      // Mobile layout
      return Positioned(
        bottom: 20,
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Show modal when not closed
            if (!_isClosed)
              Container(
                width: MediaQuery.of(context).size.width - 40,
                height: MediaQuery.of(context).size.height * 0.7,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      // Header (static on mobile)
                      _buildHeader(true),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: _selectedConversation == null
                            ? _buildConversationsList()
                            : _buildChatArea(),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Floating chat button
            _buildChatButton(totalUnread),
          ],
        ),
      );
    } else {
      // Desktop layout
      if (_isClosed) {
        // Only show floating button when closed
        return Positioned(
          bottom: 20,
          right: 20,
          child: _buildChatButton(totalUnread),
        );
      }

      // Show draggable modal when open
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = _isMinimized ? 300.0 : 400.0;
      // Calculate modal height to fit within viewport with safe margins
      final maxModalHeight = screenSize.height - 120; // Leave 120px for margins
      final modalHeight = _isMinimized ? 60.0 : (maxModalHeight.clamp(400.0, 550.0));

      // Initialize position on first build
      if (!_positionInitialized) {
        // Calculate safe initial position that ensures modal fits in viewport
        final safeInitialY = (screenSize.height - modalHeight - 80).clamp(50.0, 200.0);
        _position = Offset(
          screenSize.width - modalWidth - 20, // Start from right
          safeInitialY, // Start from top with safe margin
        );
        _positionInitialized = true;
      }

      // Ensure modal stays within screen bounds with safe margins
      final maxX = (screenSize.width - modalWidth).clamp(0.0, double.infinity);
      final maxY = (screenSize.height - modalHeight - 40).clamp(0.0, double.infinity);
      
      // Ensure minimum is not greater than maximum
      final minY = 50.0;
      final safeMaxY = maxY > minY ? maxY : minY;
      
      final constrainedPosition = Offset(
        _position.dx.clamp(0.0, maxX),
        _position.dy.clamp(minY, safeMaxY),
      );

      // Show draggable modal when open
      return Stack(
        children: [
          // Draggable modal
          Positioned(
            left: constrainedPosition.dx,
            top: constrainedPosition.dy,
            child: Container(
              width: modalWidth,
              height: modalHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (draggable on desktop)
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _isDragging = true;
                        });
                      },
                      onPanUpdate: (details) {
                        if (_position.dx != null && _position.dy != null) {
                          setState(() {
                            _position = Offset(
                              (_position.dx ?? 0) + details.delta.dx,
                              (_position.dy ?? 0) + details.delta.dy,
                            );
                          });
                        }
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _isDragging = false;
                        });
                      },
                      child: _buildHeader(false),
                    ),
                    if (!_isMinimized) ...[
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: _selectedConversation == null
                            ? _buildConversationsList()
                            : _buildChatArea(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Floating button (hide when modal is open on desktop)
          if (_isClosed)
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildChatButton(totalUnread),
            ),
        ],
      );
    }
  }

  Widget _buildChatButton(int totalUnread) {
    return GestureDetector(
      onTap: () => setState(() => _isClosed = !_isClosed),
      child: Container(
        width: 56,
        height: 56,
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
            Center(
              child: Icon(
                Icons.chat, // Always show chat icon
                color: Colors.white,
                size: 24,
              ),
            ),
            if (totalUnread > 0) // Show badge when there are unread messages
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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

  Widget _buildHeader(bool isMobile) {
    final totalUnread = _conversations.fold<int>(
      0, (sum, conv) => sum + ((conv['unread_customer_count'] as num?)?.toInt() ?? 0)
    );

    final headerWidget = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          if (!isMobile && _isDragging)
            Icon(
              Icons.drag_indicator,
              color: Colors.white,
              size: 12,
            ),
          if (!isMobile && !_isDragging)
            Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 14,
            ),
          if (isMobile)
            Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 14,
            ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Customer Support',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (totalUnread > 0)
                  Text(
                    '$totalUnread unread message${totalUnread > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 7,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (totalUnread > 0)
            Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                totalUnread > 99 ? '99+' : '$totalUnread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 1),
          if (!isMobile) // Only show minimize on desktop
            GestureDetector(
              onTap: () => setState(() => _isMinimized = !_isMinimized),
              child: Icon(
                _isMinimized ? Icons.expand : Icons.minimize,
                color: Colors.white,
                size: 12,
              ),
            ),
          if (!isMobile) const SizedBox(width: 1),
          GestureDetector(
            onTap: () => setState(() => _isClosed = true),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 12,
            ),
          ),
        ],
      ),
    );

    // Only make draggable on desktop
    if (!isMobile) {
      return GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          if (_position.dx != null && _position.dy != null) {
            setState(() {
              _position = Offset(
                (_position.dx ?? 0) + details.delta.dx,
                (_position.dy ?? 0) + details.delta.dy,
              );
            });
          }
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: headerWidget,
      );
    }

    return headerWidget;
  }

  Widget _buildConversationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading conversations',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        final conversations = snapshot.data ?? [];
        
        // Update the conversations list for badge counting
        _conversations = conversations;

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No active conversations',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final customerName = conversation['customer_name'] ?? 'Customer';
            final customerEmail = conversation['customer_email'];
            final unreadCount = (conversation['unread_customer_count'] as num?)?.toInt() ?? 0;
            final lastMessageTime = conversation['last_message_at'] != null
                ? ChatService.formatMessageTime(DateTime.parse(conversation['last_message_at']))
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                title: Text(
                  customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  customerEmail,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lastMessageTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => _selectConversation(conversation),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatArea() {
    if (_selectedConversation == null) return const SizedBox.shrink();

    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';
    final customerEmail = _selectedConversation!['customer_email'];

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedConversation = null;
                  _messages = [];
                }),
              ),
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      customerEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              final messages = snapshot.data ?? [];
              
              // Filter messages for this conversation (client-side filtering)
              final filteredMessages = messages.where((message) {
                return message['customer_email'] == customerEmail;
              }).toList();

              if (filteredMessages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: filteredMessages.length,
                itemBuilder: (context, index) {
                  final message = filteredMessages[index];
                  final isFromCustomer = message['is_from_customer'] ?? true;
                  final messageText = message['message'] ?? '';
                  final timestamp = DateTime.parse(message['created_at']).toLocal();
                  final timeStr = ChatService.formatMessageTime(timestamp);

                  return _buildMessageBubble(
                    messageText,
                    isFromCustomer,
                    timeStr,
                  );
                },
              );
            },
          ),
        ),

        // Message Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _isSending ? null : _sendMessage,
                backgroundColor: AppTheme.primaryColor,
                mini: true,
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(String message, bool isFromCustomer, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isFromCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isFromCustomer) const SizedBox(width: 40),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromCustomer ? Colors.grey.shade200 : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: Radius.circular(isFromCustomer ? 4 : 20),
                  bottomRight: Radius.circular(isFromCustomer ? 20 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isFromCustomer ? Colors.black87 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isFromCustomer 
                          ? Colors.grey.shade600 
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromCustomer) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
