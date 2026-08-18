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

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isTyping = false;
  XFile? _selectedImage;
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  String? _currentUserEmail;
  String? _currentUserName;

  // Selected quick emoji reactions store (local state for realistic feel)
  final Map<String, String> _messageReactions = {};

  final List<String> _quickSuggestions = [
    '📅 My reservation status',
    '💳 Check remaining balance',
    '🔄 Reschedule inquiry',
    '💸 Refund & Cancellation policy',
    '👨‍💼 Talk to staff',
  ];

  @override
  void initState() {
    super.initState();
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
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    _currentUserEmail = currentUser.email;
    _currentUserName = currentUser.userMetadata?['full_name'] ??
        currentUser.userMetadata?['name'] ??
        currentUser.email?.split('@')[0] ??
        'Customer';

    setState(() => _isLoading = true);

    await _getOrCreateChatSession();

    _messagesStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', currentUser.email!)
        .order('created_at', ascending: true);

    setState(() => _isLoading = false);

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
          'p_customer_name': _currentUserName ?? 'Customer',
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
          .eq('is_from_customer', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage([String? customText]) async {
    final textToSend = customText ?? _messageController.text.trim();
    if (textToSend.isEmpty && _selectedImage == null) return;
    if (_isSending || _isUploading) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      String? imageUrl;

      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        imageUrl = await ChatService().uploadChatImage(
          _selectedImage!,
          currentUser.email!,
        );
        setState(() => _isUploading = false);

        if (imageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSending = false);
          return;
        }
      }

      await ChatService().sendMessageWithImage(
        customerEmail: currentUser.email!,
        customerName: _currentUserName ?? 'Customer',
        message: textToSend,
        isFromCustomer: true,
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
          behavior: SnackBarBehavior.floating,
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

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.year == date.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildRealisticAppBar(isDesktop),
      body: Column(
        children: [
          // Realistic Message Stream Area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                image: DecorationImage(
                  image: AssetImage('assets/images/chat_bg_pattern.png'),
                  fit: BoxFit.cover,
                  opacity: 0.03,
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.forestGreen,
                        strokeWidth: 3,
                      ),
                    )
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.forestGreen,
                              strokeWidth: 3,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }

                        final dbMessages = snapshot.data ?? [];

                        if (dbMessages.isEmpty) {
                          return _buildRealisticEmptyState();
                        }

                        final List<Map<String, dynamic>> messages = [
                          {
                            'id': 'welcome_msg_static',
                            'message':
                                'Hello! 👋 Welcome to Yang Chow Customer Care. How can we make your dining or ordering experience great today?',
                            'is_from_customer': false,
                            'is_read': true,
                            'created_at': DateTime.parse(
                              dbMessages.first['created_at'],
                            )
                                .subtract(const Duration(seconds: 1))
                                .toUtc()
                                .toIso8601String(),
                          },
                          ...dbMessages,
                        ];

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          itemCount: messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length && _isSending) {
                              return _buildTypingIndicatorBubble();
                            }

                            final message = messages[index];
                            final currentCreatedAt =
                                DateTime.parse(message['created_at']).toLocal();

                            bool showDateDivider = false;
                            if (index == 0) {
                              showDateDivider = true;
                            } else {
                              final previousMessage = messages[index - 1];
                              final prevCreatedAt =
                                  DateTime.parse(previousMessage['created_at'])
                                      .toLocal();
                              showDateDivider =
                                  !_isSameDay(currentCreatedAt, prevCreatedAt);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateDivider)
                                  _buildDateDivider(currentCreatedAt),
                                _buildRealisticMessageBubble(message, index, messages),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ),

          // Suggestion Chips (Quick Responses)
          _buildQuickSuggestionsBar(),

          // Image Attachment floating tray
          if (_selectedImage != null) _buildImagePreviewTray(),

          // Realistic Floating Input Dock
          _buildRealisticInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildRealisticAppBar(bool isDesktop) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: 68,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      title: Row(
        children: [
          // Concierge Avatar with Active Glow Status
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
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
                      color: const Color(0xFF14332E).withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              // Glowing Live Online Dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Title & Realistic Live Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text(
                      'Yang Chow Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD9A441),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active now • Typically replies in 2m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
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
        // Action: Info & Help Details
        IconButton(
          tooltip: 'Help Center & Info',
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF475569),
              size: 18,
            ),
          ),
          onPressed: _showChatInfo,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          _formatMessageDate(date),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildRealisticMessageBubble(
    Map<String, dynamic> message,
    int index,
    List<Map<String, dynamic>> allMessages,
  ) {
    final isFromCustomer = message['is_from_customer'] ?? true;
    final messageText = message['message'] ?? '';
    final imageUrl = message['image_url'] as String?;
    final isRead = message['is_read'] ?? false;
    final isStaticWelcome = message['id'] == 'welcome_msg_static';
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
            isFromCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Support Agent Avatar
          if (!isFromCustomer) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFFD9A441),
                size: 18,
              ),
            ),
          ],

          // Main Bubble Container
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActionSheet(message, isFromCustomer),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
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
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF14332E),
                                    Color(0xFF1B433C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                      color: isUnsent
                          ? const Color(0xFFF1F5F9)
                          : isFromCustomer
                              ? null
                              : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isFromCustomer ? 18 : 4),
                        bottomRight: Radius.circular(isFromCustomer ? 4 : 18),
                      ),
                      border: Border.all(
                        color: isUnsent
                            ? const Color(0xFFCBD5E1)
                            : isFromCustomer
                                ? const Color(0xFF0E2420)
                                : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isFromCustomer
                              ? const Color(0xFF14332E).withOpacity(0.12)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isFromCustomer
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Image attachment if present
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _openFullscreenImage(imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 180,
                                        color: const Color(0xFFE2E8F0),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF14332E),
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) =>
                                        Container(
                                      height: 150,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (messageText.isNotEmpty && messageText != '📷 Image')
                            const SizedBox(height: 8),
                        ],

                        // Message Text Body
                        if (isUnsent)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.block_flipped,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isFromCustomer
                                    ? 'You unsent a message'
                                    : 'Message was unsent',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else if (isStaticWelcome)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.restaurant_rounded,
                                    color: Color(0xFFD9A441),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Yang Chow Concierge',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                messageText,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          )
                        else if (messageText.isNotEmpty &&
                            !(imageUrl != null && messageText == '📷 Image'))
                          Text(
                            messageText,
                            style: TextStyle(
                              color: isFromCustomer
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontSize: 14.5,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.1,
                            ),
                          ),

                        const SizedBox(height: 4),

                        // Timestamp & Message Status Checks (WhatsApp / Messenger style)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isFromCustomer
                                    ? Colors.white.withOpacity(0.7)
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isFromCustomer) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isRead
                                    ? Icons.done_all_rounded
                                    : Icons.done_all_rounded,
                                size: 14,
                                color: isRead
                                    ? const Color(0xFF67E8F9)
                                    : Colors.white.withOpacity(0.65),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Floating Emoji Reaction Badge
                  if (reaction != null)
                    Positioned(
                      bottom: -10,
                      right: isFromCustomer ? 4 : null,
                      left: isFromCustomer ? null : 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
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

  Widget _buildTypingIndicatorBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFD9A441),
              size: 18,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(200),
                const SizedBox(width: 4),
                _buildDot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFF14332E).withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildQuickSuggestionsBar() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: Color(0xFF14332E),
              ),
              label: Text(
                suggestion,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF14332E),
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pressElevation: 1,
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _sendMessage(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreviewTray() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: kIsWeb
                ? Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(
                      Icons.image_rounded,
                      color: Color(0xFF14332E),
                      size: 28,
                    ),
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Photo attached',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Ready to send with your message',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearSelectedImage,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealisticInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach image icon button
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
            const SizedBox(width: 6),

            // Message textfield capsule
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
                  focusNode: _focusNode,
                  controller: _messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
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

            // Modern Gradient Send Button
            GestureDetector(
              onTap: (_isSending || _isUploading) ? null : () => _sendMessage(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: (_isTyping || _selectedImage != null)
                      ? const LinearGradient(
                          colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: (_isTyping || _selectedImage != null)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF14332E).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
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

  Widget _buildRealisticEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD9A441), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14332E).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 44,
                  color: Color(0xFFD9A441),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Yang Chow Support',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Have a question about your order, food preparation, or reservation? Our team is live and ready to assist you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFD9A441),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Instant live chat connected',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unable to connect to chat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _initializeChat,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActionSheet(Map<String, dynamic> message, bool isFromCustomer) {
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
            // Emoji quick reactions
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
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Copy text action
            if (messageText.isNotEmpty &&
                messageText != ChatService.unsentMessageSentinel)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF334155)),
                title: const Text('Copy Message Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: messageText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

            // Unsend action (for customer's own messages)
            if (isFromCustomer &&
                messageText != ChatService.unsentMessageSentinel)
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: AppTheme.errorRed),
                title: const Text(
                  'Unsend Message',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showUnsendDialog(messageId);
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
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
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

  void _showUnsendDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Unsend message?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will remove the message for everyone in the chat.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ChatService().unsendMessage(messageId);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to unsend message'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => _ConciergeHelpHubDialog(
        onSendMessage: (msg) {
          _sendMessage(msg);
        },
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATEFUL CONCIERGE HELP HUB (BOUND TO REAL SYSTEM MODULES)
// ══════════════════════════════════════════════════════════════════════════════
class _ConciergeHelpHubDialog extends StatefulWidget {
  final Function(String) onSendMessage;

  const _ConciergeHelpHubDialog({required this.onSendMessage});

  @override
  State<_ConciergeHelpHubDialog> createState() => _ConciergeHelpHubDialogState();
}

class _ConciergeHelpHubDialogState extends State<_ConciergeHelpHubDialog> {
  int _currentView = 0; // 0: Menu, 1: Reservations & Balance, 2: Reschedule Requests, 3: Cancellations & Refunds

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 1:
        return _buildReservationsView();
      case 2:
        return _buildRescheduleView();
      case 3:
        return _buildRefundsView();
      case 0:
      default:
        return _buildMainMenuView();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW 0: MAIN SERVICES MENU
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMainMenuView() {
    return Column(
      key: const ValueKey('menu_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF14332E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF14332E),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help Center & System Services',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Select a system feature to check or inquire',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Service 1: My Reservations & Balance Tracker
        _buildMenuButton(
          icon: Icons.calendar_month_rounded,
          title: 'My Reservations & Balance',
          description: 'Check active bookings, event schedule, pax & remaining balance',
          badgeText: 'Reservations',
          badgeColor: const Color(0xFF10B981),
          onPressed: () => setState(() => _currentView = 1),
        ),
        const SizedBox(height: 10),

        // Service 2: Reschedule Requests
        _buildMenuButton(
          icon: Icons.event_repeat_rounded,
          title: 'Reschedule Requests',
          description: 'Track requested event date/time changes & approval status',
          badgeText: 'Reschedules',
          badgeColor: const Color(0xFF3B82F6),
          onPressed: () => setState(() => _currentView = 2),
        ),
        const SizedBox(height: 10),

        // Service 3: Cancellation & Refund Status
        _buildMenuButton(
          icon: Icons.assignment_return_rounded,
          title: 'Cancellations & Refund Status',
          description: 'Check refund requests, policy calculation & review status',
          badgeText: 'Refund Policy',
          badgeColor: const Color(0xFFD9A441),
          onPressed: () => setState(() => _currentView = 3),
        ),
        const SizedBox(height: 16),

        // Hours banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: const [
              Icon(Icons.schedule_rounded, color: Color(0xFF14332E), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operating Hours: 9:00 AM – 9:00 PM Daily',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Back to Chat',
            style: TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF14332E).withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF14332E), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF94A3B8),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW 1: MY RESERVATIONS & REMAINING BALANCE TRACKER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReservationsView() {
    return Column(
      key: const ValueKey('reservations_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentView = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'My Reservations & Balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Flexible(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchCustomerReservations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF14332E)),
                  ),
                );
              }

              final reservations = snapshot.data ?? [];

              if (reservations.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'No reservations found under your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You can ask support to check your reservation status.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSendMessage(
                            '📅 Hi Support, I would like to inquire about my reservation details and balance.',
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Inquire in Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: reservations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final res = reservations[index];
                  final rawId = (res['id'] ?? '').toString();
                  final resId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId;
                  final eventType = res['event_type'] ?? res['reservation_type'] ?? 'Dining Reservation';
                  final status = (res['status'] ?? res['reservation_status'] ?? 'Pending').toString();
                  final date = (res['event_date'] ?? res['reservation_date'] ?? res['order_date'] ?? '').toString().split('T')[0];
                  final time = res['start_time'] ?? res['event_time'] ?? res['time_slot'] ?? res['order_time'] ?? '';
                  final pax = res['guests'] ?? res['pax'] ?? 'N/A';
                  final total = res['total_amount'] ?? res['package_amount'] ?? 0;
                  final paid = res['downpayment_amount'] ?? res['payment_amount'] ?? res['downpayment'] ?? 0;
                  final remaining = res['remaining_balance'] ?? (total > paid ? total - paid : 0);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$eventType #${resId.isEmpty ? index + 1 : resId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              '$date $time'.trim(),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 14),
                            const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              '$pax Guests',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Package', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  Text('₱$total', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Paid / Downpayment', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  Text('₱$paid', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Remaining Balance', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  Text('₱$remaining', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSendMessage(
                                '📅 Hi Support, I want to inquire about my Reservation #${resId.isEmpty ? index + 1 : resId} ($eventType on $date, Status: $status, Remaining Balance: ₱$remaining).',
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Inquire About This Reservation in Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14332E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCustomerReservations() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.email == null) return [];

    final email = currentUser!.email!.trim();
    final lowerEmail = email.toLowerCase();
    final List<Map<String, dynamic>> combined = [];

    // 1. Fetch from 'reservations' table using customer_email or email
    try {
      final res = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail,email.eq.$email,email.eq.$lowerEmail')
          .order('created_at', ascending: false)
          .limit(10);

      for (final r in res) {
        combined.add({
          ...r,
          '_type': 'reservation',
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer reservations with OR: $e');
      try {
        final res = await Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', email)
            .order('created_at', ascending: false)
            .limit(10);
        for (final r in res) {
          combined.add({...r, '_type': 'reservation'});
        }
      } catch (_) {}
    }

    // 2. Fetch from 'advance_orders' table
    try {
      final orders = await Supabase.instance.client
          .from('advance_orders')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
          .order('created_at', ascending: false)
          .limit(10);

      for (final o in orders) {
        combined.add({
          ...o,
          '_type': 'advance_order',
          'event_type': 'Advance Order (${o['order_type'] ?? 'Food'})',
          'event_date': o['order_date'] ?? o['created_at'],
          'start_time': o['order_time'] ?? '',
          'guests': o['pax'] ?? o['guests'] ?? 'N/A',
          'total_amount': o['total_amount'] ?? 0,
          'downpayment_amount': o['paid_amount'] ?? o['downpayment'] ?? o['total_amount'] ?? 0,
          'remaining_balance': o['remaining_balance'] ?? 0,
          'status': o['status'] ?? o['payment_status'] ?? 'Confirmed',
        });
      }
    } catch (e) {
      debugPrint('Error fetching advance orders: $e');
    }

    // Sort by created_at descending
    combined.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return combined;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW 2: RESCHEDULE REQUESTS TRACKER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRescheduleView() {
    return Column(
      key: const ValueKey('reschedule_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentView = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Reschedule Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Flexible(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchCustomerReschedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF14332E)),
                  ),
                );
              }

              final reschedules = snapshot.data ?? [];

              if (reschedules.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_repeat_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'No reschedule requests found',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You can request a new date or time through the chat support.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSendMessage(
                            '🔄 Hi Support, I would like to request to reschedule my reservation date/time.',
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send Reschedule Inquiry in Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: reschedules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final req = reschedules[index];
                  final resId = req['reservation_id']?.toString().substring(0, 8).toUpperCase() ?? '';
                  final oldDate = '${req['old_date'] ?? ''} ${req['old_time'] ?? ''}';
                  final newDate = '${req['new_date'] ?? ''} ${req['new_time'] ?? ''}';
                  final status = (req['status'] ?? 'pending').toString();
                  final reason = req['reason'] ?? 'No reason provided';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Request for #${resId.isEmpty ? index + 1 : resId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Original: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            Text(oldDate, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('Requested: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            Text(newDate, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF14332E))),
                          ],
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Reason: $reason', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSendMessage(
                                '🔄 Hi Support, I am following up on my Reschedule Request for Reservation #$resId (Moving from $oldDate to $newDate, Status: $status).',
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Follow Up Reschedule in Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14332E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCustomerReschedules() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.email == null) return [];

    final email = currentUser!.email!.trim();
    final lowerEmail = email.toLowerCase();
    try {
      final reqs = await Supabase.instance.client
          .from('reschedule_requests')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(reqs);
    } catch (e) {
      debugPrint('Error fetching reschedules: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW 3: CANCELLATIONS & REFUND POLICY STATUS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRefundsView() {
    return SingleChildScrollView(
      key: const ValueKey('refunds_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _currentView = 0),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Cancellations & Refund Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // System Refund Policy Summary Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '📋 Yang Chow Cancellation & Refund Policy',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                ),
                SizedBox(height: 6),
                Text(
                  '• 4+ Days Before Event: 100% Full Refund of downpayment\n• 1–3 Days Before Event: 50% Partial Refund\n• Event Day / Passed: Non-refundable',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Your Cancellation / Refund Requests:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchCustomerRefundRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF14332E)),
                  ),
                );
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                      SizedBox(height: 6),
                      Text(
                        'No pending cancellation or refund tickets',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF334155)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'All your reservations are active.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: requests.map((req) {
                  final rawId = (req['source_id'] ?? req['id'] ?? '').toString();
                  final shortId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId;
                  final status = (req['status'] ?? 'pending').toString();
                  final refundAmount = req['refund_amount'] ?? 0;
                  final reason = req['reason'] ?? 'Requested by customer';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cancellation for #${shortId.isEmpty ? 'N/A' : shortId}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text('Reason: $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text('Refund Amount: ₱$refundAmount', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                            ],
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onSendMessage(
                '💸 Hi Support, I have an inquiry regarding the cancellation and refund policy for my reservation. Could you assist me?',
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Inquire About Cancellation / Refund in Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCustomerRefundRequests() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.email == null) return [];

    final email = currentUser!.email!.trim();
    final lowerEmail = email.toLowerCase();
    final List<Map<String, dynamic>> combined = [];

    // 1. Fetch from 'refunds' table (Primary refund management table)
    try {
      final refundsList = await Supabase.instance.client
          .from('refunds')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
          .order('created_at', ascending: false)
          .limit(10);

      for (final r in refundsList) {
        combined.add({
          'id': r['id'],
          'source_id': r['source_id'] ?? r['id'],
          'status': r['status'] ?? 'pending',
          'refund_amount': r['refund_amount'] ?? 0,
          'reason': r['refund_reason'] ?? r['reason'] ?? 'Customer Refund Request',
          'created_at': r['created_at'],
        });
      }
    } catch (e) {
      debugPrint('Error fetching from refunds table: $e');
    }

    // 2. Fetch from 'cancellation_requests' table
    try {
      final cancelList = await Supabase.instance.client
          .from('cancellation_requests')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail')
          .order('created_at', ascending: false)
          .limit(10);

      for (final c in cancelList) {
        final srcId = (c['reservation_id'] ?? c['id'])?.toString();
        final exists = combined.any((item) => item['source_id']?.toString() == srcId);
        if (!exists) {
          combined.add({
            'id': c['id'],
            'source_id': srcId,
            'status': c['status'] ?? 'pending',
            'refund_amount': c['refund_amount'] ?? 0,
            'reason': c['cancellation_reason'] ?? 'Cancelled by Customer',
            'created_at': c['created_at'],
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching from cancellation_requests table: $e');
    }

    // 3. Fetch directly from 'reservations' table where status is cancelled
    try {
      final cancelledRes = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .or('customer_email.eq.$email,customer_email.eq.$lowerEmail,email.eq.$email,email.eq.$lowerEmail')
          .eq('status', 'cancelled')
          .order('created_at', ascending: false)
          .limit(10);

      for (final res in cancelledRes) {
        final resId = res['id']?.toString();
        final exists = combined.any((item) => item['source_id']?.toString() == resId || item['id']?.toString() == resId);
        if (!exists) {
          combined.add({
            'id': res['id'],
            'source_id': resId,
            'status': res['refund_status'] ?? res['status'] ?? 'cancelled',
            'refund_amount': res['refund_amount'] ?? 0,
            'reason': res['cancellation_reason'] ?? 'Cancelled Reservation (${res['event_type'] ?? 'Dining'})',
            'created_at': res['created_at'],
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching cancelled reservations: $e');
    }

    // Sort all combined records by created_at descending
    combined.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return combined;
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    final lower = status.toLowerCase();
    if (lower.contains('confirm') || lower.contains('approved') || lower.contains('completed')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (lower.contains('pending') || lower.contains('review')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (lower.contains('prepar') || lower.contains('kitchen')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (lower.contains('cancel') || lower.contains('reject')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
