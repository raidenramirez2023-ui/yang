import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/chat_service.dart';

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    debugPrint('Initializing chat for user: ${currentUser.email}');

    setState(() => _isLoading = true);

    // Create or get chat session
    await _getOrCreateChatSession();

    // Set up stream for messages
    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', currentUser.email!)
        .order('created_at', ascending: true);

    debugPrint('Chat stream set up for: ${currentUser.email}');

    setState(() => _isLoading = false);

    // Mark messages as read when they're loaded
    _markMessagesAsRead();
  }

  Future<void> _getOrCreateChatSession() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client.rpc(
        'get_or_create_chat_session',
        params: {
          'p_customer_email': currentUser.email!,
          'p_customer_name':
              currentUser.userMetadata?['full_name'] ??
              currentUser.userMetadata?['name'] ??
              currentUser.email?.split('@')[0] ??
              'Customer',
        },
      );
    } catch (e) {
      debugPrint('Error creating chat session: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('customer_email', currentUser.email!)
          .eq('is_from_customer', false); // Only mark admin messages as read
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'customer_email': currentUser.email!,
        'customer_name':
            currentUser.userMetadata?['full_name'] ??
            currentUser.userMetadata?['name'] ??
            currentUser.email?.split('@')[0] ??
            'Customer',
        'message': _messageController.text.trim(),
        'is_from_customer': true,
        'is_read': false,
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F7FA,
      ), // Professional business background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            // Profile picture circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor, // Professional Red
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.successGreen, // Professional green
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGrey, // Professional grey
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Unread messages indicator
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final unreadAdminMessages = snapshot.data!
                    .where(
                      (msg) =>
                          msg['is_from_customer'] == false &&
                          msg['is_read'] == false,
                    )
                    .length;

                if (unreadAdminMessages > 0) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor, // Professional red
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '$unreadAdminMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.info, color: AppTheme.mediumGrey),
              onPressed: _showChatInfo,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages List with business-style background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFF5F7FA), const Color(0xFFECF0F1)],
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        debugPrint(
                          'StreamBuilder state: ${snapshot.connectionState}',
                        );
                        debugPrint('Has error: ${snapshot.hasError}');
                        debugPrint('Has data: ${snapshot.hasData}');
                        if (snapshot.hasData) {
                          debugPrint(
                            'Messages count: ${snapshot.data?.length}',
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint('Stream error: ${snapshot.error}');
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading messages',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please try again',
                                  style: TextStyle(color: AppTheme.mediumGrey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final dbMessages = snapshot.data ?? [];

                        if (dbMessages.isEmpty) {
                          debugPrint('No messages found, showing empty state');
                          return _buildBusinessEmptyState();
                        }

                        // Prepend a welcome message to the list so it's always the first message in the history
                        final List<Map<String, dynamic>> messages = [
                          {
                            'id': 'welcome_msg_static',
                            'message': 'Welcome to Customer Support! 👋\nHow can I help you?',
                            'is_from_customer': false,
                            'is_read': true,
                            'created_at': DateTime.parse(dbMessages.first['created_at'])
                                .subtract(const Duration(seconds: 1))
                                .toIso8601String(),
                          },
                          ...dbMessages,
                        ];

                        debugPrint('Displaying ${messages.length} messages');

                        // Scroll to bottom when new messages arrive
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 16,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _buildBusinessMessageBubble(message);
                          },
                        );
                      },
                    ),
            ),
          ),

          // Business-style input area
          _buildBusinessInput(),
        ],
      ),
    );
  }

  Widget _buildBusinessEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Customer Support',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hi! Welcome to our support. 👋\nHow can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick response guaranteed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessMessageBubble(Map<String, dynamic> message) {
    final isFromCustomer = message['is_from_customer'] ?? true;
    final messageText = message['message'] ?? '';
    final timestamp = DateTime.parse(message['created_at']).toLocal();
    final timeStr = DateFormat('h:mm a').format(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isFromCustomer
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isFromCustomer) ...[
            // Support agent avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor, // Support agent in Red
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isFromCustomer
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress:
                      isFromCustomer &&
                              messageText != ChatService.unsentMessageSentinel
                          ? () => _showUnsendDialog(message['id'].toString())
                          : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                      minWidth: 60,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: messageText == ChatService.unsentMessageSentinel
                          ? Colors.grey.withValues(alpha: 0.1)
                          : isFromCustomer
                              ? AppTheme.primaryColor
                              : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomLeft: isFromCustomer
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: isFromCustomer
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      border: !isFromCustomer ||
                              messageText == ChatService.unsentMessageSentinel
                          ? Border.all(
                              color: const Color(0xFFECF0F1),
                              width: 1,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: message['id'] == 'welcome_msg_static'
                        ? RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 15,
                                height: 1.5,
                                fontFamily: 'Inter', // Assuming Inter or similar is used
                              ),
                              children: [
                                const TextSpan(text: 'Welcome to '),
                                const TextSpan(
                                  text: 'Customer Support! 👋',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const TextSpan(
                                  text: '\nHow can I help you?',
                                  style: TextStyle(height: 1.8),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            messageText == ChatService.unsentMessageSentinel
                                ? (isFromCustomer
                                    ? 'You unsent a message'
                                    : 'This message was unsent')
                                : messageText,
                            style: TextStyle(
                              color: messageText == ChatService.unsentMessageSentinel
                                  ? AppTheme.mediumGrey
                                  : isFromCustomer
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                              fontSize: 15,
                              height: 1.4,
                              fontStyle:
                                  messageText == ChatService.unsentMessageSentinel
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                              fontWeight: isFromCustomer
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: EdgeInsets.only(
                    left: isFromCustomer ? 0 : 40,
                    right: isFromCustomer ? 40 : 0,
                    top: 2,
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isFromCustomer) ...[
            // Customer avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFECF0F1), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add attachment button
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                // TODO: Add attachment functionality
              },
              icon: const Icon(
                Icons.attach_file,
                color: AppTheme.mediumGrey,
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF5F7FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // Message input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFECF0F1)),
              ),
              child: TextField(
                controller: _messageController,
                onChanged: (text) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  hintStyle: TextStyle(color: AppTheme.mediumGrey, fontSize: 15),
                ),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Send button
          Container(
            decoration: BoxDecoration(
              color: _isSending
                   ? AppTheme.lightGrey
                   : AppTheme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: _isSending
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IconButton(
              mouseCursor: SystemMouseCursors.click,
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.mediumGrey,
                        ),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsendDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend message?'),
        content: const Text(
          'Unsending will remove this message from the chat for everyone. People in the chat may have already seen it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mediumGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ChatService().unsendMessage(messageId);
              if (!success) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to unsend message'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            },
            child: const Text(
              'Unsend',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppTheme.primaryColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Chat Support',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'How can we help you today?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Help categories
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHelpItem(
                      icon: Icons.event,
                      title: 'Reservations',
                      description: 'Questions about booking and availability',
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem(
                      icon: Icons.help_outline,
                      title: 'General Help',
                      description: 'Assistance with our services',
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem(
                      icon: Icons.star,
                      title: 'Special Requests',
                      description: 'Custom accommodations and arrangements',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Response time indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We typically respond within minutes during business hours',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
