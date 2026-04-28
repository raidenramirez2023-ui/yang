import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/chat_service.dart';
import 'package:image_picker/image_picker.dart';

class AdminChatPage extends StatefulWidget {
  const AdminChatPage({super.key});

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? _selectedConversation;
  bool _isSending = false;
  bool _isUploading = false;
  XFile? _selectedImage;
  Stream<List<Map<String, dynamic>>>? _conversationsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Set up stream for conversations
    _conversationsStream = Supabase.instance.client
        .from('chat_sessions')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false);
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    debugPrint(
      'Admin selecting conversation: ${conversation['customer_email']}',
    );
    setState(() {
      _selectedConversation = conversation;
    });

    final customerEmail = conversation['customer_email'];
    debugPrint('Setting up message stream for: $customerEmail');

    // Set up stream for messages in this conversation
    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail)
        .order('created_at', ascending: true);

    // Mark messages as read
    _markMessagesAsRead(customerEmail);
  }

  Future<void> _markMessagesAsRead(String customerEmail) async {
    try {
      await Supabase.instance.client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('customer_email', customerEmail)
          .eq('is_from_customer', true); // Only mark customer messages as read
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedConversation == null) {
      return;
    }

    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;
    if (_isSending || _isUploading) return;

    final customerEmail = _selectedConversation!['customer_email'];
    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        imageUrl = await ChatService().uploadChatImage(
          _selectedImage!,
          customerEmail,
        );
        setState(() => _isUploading = false);
        
        if (imageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          setState(() => _isSending = false);
          return;
        }
      }

      await ChatService().sendMessageWithImage(
        customerEmail: customerEmail,
        customerName: customerName,
        message: _messageController.text.trim(),
        isFromCustomer: false,
        imageUrl: imageUrl,
      );

      _messageController.clear();
      setState(() => _selectedImage = null);
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
      if (mounted) {
        setState(() {
          _isSending = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pick image'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _clearSelectedImage() {
    setState(() => _selectedImage = null);
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.support_agent),
            const SizedBox(width: 12),
            const Text('Customer Support Chat'),
            if (!isDesktop && _selectedConversation != null) ...[
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedConversation = null),
              ),
            ],
          ],
        ),
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Conversations List
        Container(
          width: 350,
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _conversationsStream,
                      builder: (context, snapshot) {
                        final totalUnread =
                            snapshot.data?.fold<int>(
                              0,
                              (sum, conv) =>
                                  sum +
                                  ((conv['unread_customer_count'] as num?)
                                          ?.toInt() ??
                                      0),
                            ) ??
                            0;

                        if (totalUnread > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalUnread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              // Conversations List
              Expanded(child: _buildConversationsList()),
            ],
          ),
        ),

        // Chat Area
        Expanded(
          child: _selectedConversation != null
              ? _buildChatArea()
              : _buildEmptySelection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedConversation != null) {
      return _buildChatArea();
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Text(
                'Customer Conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // Conversations List
        Expanded(child: _buildConversationsList()),
      ],
    );
  }

  Widget _buildConversationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
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
                  'Error loading conversations',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer chats will appear here',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _buildConversationItem(conversation);
          },
        );
      },
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final isSelected =
        _selectedConversation?['id'] == conversation['id'];
    final customerName = conversation['customer_name'] ?? 'Customer';
    final customerEmail = conversation['customer_email'];
    final unreadCount = conversation['unread_customer_count'] ?? 0;
    final lastMessageTime = conversation['last_message_time'] != null
        ? DateTime.parse(conversation['last_message_time']).toLocal()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        onTap: () => _selectConversation(conversation),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: AppTheme.primaryColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                customerName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customerEmail,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
            if (lastMessageTime != null)
              Text(
                _formatLastMessageTime(lastMessageTime),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20)
            : null,
      ),
    );
  }

  Widget _buildEmptySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a conversation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a customer conversation from the list\nto start chatting',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_selectedConversation == null) return const SizedBox.shrink();

    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';
    final customerEmail = _selectedConversation!['customer_email'];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppTheme.primaryColor),
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
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        customerEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!ResponsiveUtils.isDesktop(context))
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _selectedConversation = null),
                  ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                debugPrint(
                  'Admin StreamBuilder state: ${snapshot.connectionState}',
                );
                debugPrint('Admin has error: ${snapshot.hasError}');
                debugPrint('Admin has data: ${snapshot.hasData}');
                if (snapshot.hasData) {
                  debugPrint('Admin messages count: ${snapshot.data?.length}');
                }
                if (snapshot.hasError) {
                  debugPrint('Admin stream error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
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
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  debugPrint('Admin: No messages found, showing empty state');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                debugPrint('Admin displaying ${messages.length} messages');

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isFromCustomer = message['is_from_customer'] ?? true;
    final messageText = message['message'] ?? '';
    final imageUrl = message['image_url'] as String?;
    final timestamp = DateTime.parse(message['created_at']).toLocal();
    final timeStr = DateFormat('h:mm a').format(timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isFromCustomer
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isFromCustomer
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (isFromCustomer) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress:
                      !isFromCustomer &&
                              messageText != ChatService.unsentMessageSentinel
                          ? () => _showUnsendDialog(message['id'].toString())
                          : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: messageText == ChatService.unsentMessageSentinel
                          ? Colors.grey.withOpacity(0.1)
                          : isFromCustomer
                              ? Colors.grey.shade100
                              : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomLeft: Radius.circular(isFromCustomer ? 4 : 20),
                        bottomRight: Radius.circular(isFromCustomer ? 20 : 4),
                      ),
                      border: messageText == ChatService.unsentMessageSentinel
                          ? Border.all(color: Colors.grey.shade300)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (messageText.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (messageText.isNotEmpty)
                          Text(
                            messageText == ChatService.unsentMessageSentinel
                                ? (!isFromCustomer
                                    ? 'You unsent a message'
                                    : 'This message was unsent')
                                : messageText,
                            style: TextStyle(
                              color: messageText == ChatService.unsentMessageSentinel
                                  ? Colors.grey.shade600
                                  : isFromCustomer
                                      ? Colors.black87
                                      : Colors.white,
                              fontSize: 16,
                              fontStyle:
                                  messageText == ChatService.unsentMessageSentinel
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isFromCustomer) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              left: isFromCustomer ? 32 : 0,
              right: isFromCustomer ? 0 : 32,
            ),
            child: Text(
              timeStr,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _pickImage,
              icon: const Icon(
                Icons.attach_file,
                color: Colors.grey,
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedImage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 30,
                                  ),
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Image selected',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSelectedImage,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your response...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isSending || _isUploading ? Colors.grey.shade300 : AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: (_isSending || _isUploading) ? null : _sendMessage,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                color: Color(0xFFE74C3C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
