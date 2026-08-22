import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _selectedConversation;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isTyping = false;
  XFile? _selectedImage;
  String _searchQuery = '';

  Stream<List<Map<String, dynamic>>>? _conversationsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  Map<String, String> _messageReactions = {};

  final List<String> _cannedReplies = [
    '👋 Hello! How may we assist with your reservation today?',
    '✅ Your reservation is confirmed! We look forward to serving you.',
    '💳 We have verified your downpayment / remaining balance. Thank you!',
    '🔄 Your reschedule request is currently being reviewed by our management.',
    '📋 You can check your refund policy & cancellation status anytime in Help Center.',
  ];

  @override
  void initState() {
    super.initState();
    _searchQuery = '';
    _messageReactions = {};
    _isTyping = false;
    _initializeChat();
    _messageController.addListener(() {
      final isNowTyping = _messageController.text.trim().isNotEmpty;
      if (isNowTyping != (_isTyping)) {
        setState(() => _isTyping = isNowTyping);
      }
    });
  }

  Future<void> _initializeChat() async {
    _conversationsStream = Supabase.instance.client
        .from('chat_sessions')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false);
  }

  void _selectConversation(Map<String, dynamic> conversation) {
    setState(() {
      _selectedConversation = conversation;
    });

    final customerEmail = conversation['customer_email'];

    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail)
        .order('created_at', ascending: true);

    _markMessagesAsRead(customerEmail);
  }

  Future<void> _markMessagesAsRead(String customerEmail) async {
    try {
      await Supabase.instance.client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('customer_email', customerEmail)
          .eq('is_from_customer', true);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage([String? customText]) async {
    if (_selectedConversation == null) return;

    final textToSend = customText ?? _messageController.text.trim();
    if (textToSend.isEmpty && _selectedImage == null) return;
    if (_isSending || _isUploading) return;

    final customerEmail = _selectedConversation!['customer_email'];
    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';

    setState(() => _isSending = true);

    try {
      String? imageUrl;

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
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSending = false);
          return;
        }
      }

      await ChatService().sendMessageWithImage(
        customerEmail: customerEmail,
        customerName: customerName,
        message: textToSend,
        isFromCustomer: false,
        imageUrl: imageUrl,
      );

      if (customText == null) {
        _messageController.clear();
      }
      setState(() => _selectedImage = null);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
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
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return PopScope(
      canPop: _selectedConversation == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedConversation != null) {
          setState(() => _selectedConversation = null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Conversation Sidebar
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Column(
            children: [
              _buildSidebarHeader(),
              _buildSearchBar(),
              Expanded(child: _buildConversationsList()),
            ],
          ),
        ),

        // Right: Active Chat Room
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

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(),
          _buildSearchBar(),
          Expanded(child: _buildConversationsList()),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Color(0xFFD9A441),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Live Chat Inbox',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _conversationsStream,
            builder: (context, snapshot) {
              final totalUnread = snapshot.data?.fold<int>(
                    0,
                    (sum, conv) =>
                        sum +
                        ((conv['unread_customer_count'] as num?)?.toInt() ?? 0),
                  ) ??
                  0;

              if (totalUnread > 0) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$totalUnread New',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search customer name or email...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF14332E),
              strokeWidth: 2.5,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading chats: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
              ),
            ),
          );
        }

        var conversations = snapshot.data ?? [];
        final query = _searchQuery.trim().toLowerCase();

        if (query.isNotEmpty) {
          conversations = conversations.where((c) {
            final name = (c['customer_name'] ?? '').toString().toLowerCase();
            final email = (c['customer_email'] ?? '').toString().toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No conversations found',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _buildConversationListItem(conversation);
          },
        );
      },
    );
  }

  Widget _buildConversationListItem(Map<String, dynamic> conversation) {
    final isSelected = _selectedConversation?['id'] == conversation['id'];
    final customerName = conversation['customer_name'] ?? 'Customer';
    final customerEmail = conversation['customer_email'] ?? '';
    final unreadCount =
        (conversation['unread_customer_count'] as num?)?.toInt() ?? 0;
    final lastMessageTime = conversation['last_message_at'] != null
        ? DateTime.parse(conversation['last_message_at']).toLocal()
        : null;

    final initial = customerName.isNotEmpty
        ? customerName[0].toUpperCase()
        : customerEmail.isNotEmpty
            ? customerEmail[0].toUpperCase()
            : 'C';

    return InkWell(
      onTap: () => _selectConversation(conversation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? const Color(0xFF14332E).withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            // Customer Avatar with fallback initial
            CircleAvatar(
              radius: 22,
              backgroundColor: isSelected
                  ? const Color(0xFF14332E)
                  : const Color(0xFFE2E8F0),
              child: Text(
                initial,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name & Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontWeight: isSelected || unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMessageTime != null)
                        Text(
                          ChatService.formatMessageTime(lastMessageTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: unreadCount > 0
                                ? const Color(0xFF14332E)
                                : const Color(0xFF94A3B8),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customerEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14332E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14332E).withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.support_agent_rounded,
                size: 52,
                color: Color(0xFFD9A441),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Yang Chow Support Console',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a customer conversation from the left to start responding.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    final customerName = _selectedConversation!['customer_name'] ?? 'Customer';
    final customerEmail = _selectedConversation!['customer_email'];

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Active Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                if (!ResponsiveUtils.isDesktop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        setState(() => _selectedConversation = null),
                  ),
                  const SizedBox(width: 4),
                ],
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF14332E),
                  child: Text(
                    customerName.isNotEmpty
                        ? customerName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        customerEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message Stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF14332E),
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet in this conversation',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final currentCreatedAt =
                        DateTime.parse(message['created_at']).toLocal();

                    bool showDateDivider = false;
                    if (index == 0) {
                      showDateDivider = true;
                    } else {
                      final prevCreatedAt =
                          DateTime.parse(messages[index - 1]['created_at'])
                              .toLocal();
                      showDateDivider =
                          !_isSameDay(currentCreatedAt, prevCreatedAt);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateDivider)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                _formatDateDivider(currentCreatedAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        _buildAdminMessageBubble(message, index),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Canned Responses Pills
          _buildCannedResponsesBar(),

          // Image Preview Tray
          if (_selectedImage != null) _buildAdminImagePreview(),

          // Input Bar
          _buildAdminInputBar(),
        ],
      ),
    );
  }

  Widget _buildAdminMessageBubble(Map<String, dynamic> message, int index) {
    final rawIsFromCustomer = message['is_from_customer'] ?? true;
    final isBot = message['customer_name']?.toString().contains('Concierge') == true ||
                  message['customer_name']?.toString().contains('Bot') == true ||
                  message['message']?.toString().startsWith('📅 **How to Book') == true ||
                  message['message']?.toString().startsWith('💳 **Payment') == true ||
                  message['message']?.toString().startsWith('💸 **Live Refund') == true ||
                  message['message']?.toString().startsWith('🔄 **Live Reschedule') == true ||
                  message['message']?.toString().startsWith('📅 **Live Reservation') == true ||
                  message['message']?.toString().startsWith('💸 **Cancellation') == true ||
                  message['message']?.toString().startsWith('📊 **Tracking Status') == true;
    final isFromCustomer = rawIsFromCustomer && !isBot;
    final messageText = message['message'] ?? '';
    final imageUrl = message['image_url'] as String?;
    final isUnsent = messageText == ChatService.unsentMessageSentinel;

    DateTime timestamp;
    try {
      timestamp = DateTime.parse(message['created_at']).toLocal();
    } catch (_) {
      timestamp = DateTime.now();
    }
    final timeStr = DateFormat('h:mm a').format(timestamp);
    final messageId = message['id']?.toString() ?? '$index';
    final reaction = _messageReactions[messageId];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isFromCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFromCustomer) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              child: const Icon(
                Icons.person_rounded,
                size: 16,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () =>
                  _showAdminMessageActionSheet(message, isFromCustomer),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                      minWidth: 70,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUnsent
                          ? null
                          : isFromCustomer
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF14332E),
                                    Color(0xFF1B433C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                      color: isUnsent
                          ? const Color(0xFFF1F5F9)
                          : isFromCustomer
                              ? Colors.white
                              : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isFromCustomer ? 4 : 18),
                        bottomRight: Radius.circular(isFromCustomer ? 18 : 4),
                      ),
                      border: Border.all(
                        color: isUnsent
                            ? const Color(0xFFCBD5E1)
                            : isFromCustomer
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF0E2420),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isFromCustomer
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _openFullscreenImage(imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (messageText.isNotEmpty &&
                              messageText != '📷 Image')
                            const SizedBox(height: 6),
                        ],
                        if (isUnsent)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.block_flipped,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Message was unsent',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else if (messageText.isNotEmpty &&
                            !(imageUrl != null && messageText == '📷 Image')) ...[
                          if (!isFromCustomer && (message['customer_name']?.toString().contains('Concierge') == true || message['customer_name']?.toString().contains('Bot') == true))
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.smart_toy_rounded, size: 11, color: Color(0xFFD9A441)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Yang Chow Concierge (Bot)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            messageText,
                            style: TextStyle(
                              color: isFromCustomer
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isFromCustomer
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reaction != null)
                    Positioned(
                      bottom: -10,
                      right: isFromCustomer ? null : 4,
                      left: isFromCustomer ? 4 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(reaction, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCannedResponsesBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cannedReplies.length,
        itemBuilder: (context, index) {
          final reply = _cannedReplies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                reply,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF14332E),
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: () => _sendMessage(reply),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.image, color: Color(0xFF14332E)),
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Image attached to response',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _clearSelectedImage,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach Image',
              onPressed: _pickImage,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Color(0xFF475569),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isTyping
                        ? const Color(0xFF14332E)
                        : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Reply as Admin support...',
                    hintStyle:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: (_isSending || _isUploading) ? null : () => _sendMessage(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: (_isTyping || _selectedImage != null)
                      ? const LinearGradient(
                          colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isUploading || _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminMessageActionSheet(
    Map<String, dynamic> message,
    bool isFromCustomer,
  ) {
    final messageId = message['id']?.toString() ?? '';
    final messageText = message['message'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '👍', '🍜', '🔥', '😮', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _messageReactions[messageId] = emoji;
                      });
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (messageText.isNotEmpty &&
                messageText != ChatService.unsentMessageSentinel)
              ListTile(
                leading:
                    const Icon(Icons.copy_rounded, color: Color(0xFF334155)),
                title: const Text('Copy Message Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: messageText));
                  Navigator.pop(context);
                },
              ),
            if (!isFromCustomer &&
                messageText != ChatService.unsentMessageSentinel)
              ListTile(
                leading:
                    const Icon(Icons.undo_rounded, color: AppTheme.errorRed),
                title: const Text(
                  'Unsend Message',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ChatService().unsendMessage(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
