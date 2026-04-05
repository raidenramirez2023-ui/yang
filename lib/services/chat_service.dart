import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream for all conversations (for admin)
  Stream<List<Map<String, dynamic>>> getConversationsStream() {
    return _supabase
        .from('admin_chat_conversations')
        .stream(primaryKey: ['session_id'])
        .order('last_message_at', ascending: false);
  }

  // Stream for messages in a specific conversation
  Stream<List<Map<String, dynamic>>> getMessagesStream(String customerEmail) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail)
        .order('created_at', ascending: true);
  }

  // Stream for customer's own messages
  Stream<List<Map<String, dynamic>>> getCustomerMessagesStream(String customerEmail) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail)
        .order('created_at', ascending: true);
  }

  // Send a message
  Future<bool> sendMessage({
    required String customerEmail,
    required String customerName,
    required String message,
    required bool isFromCustomer,
  }) async {
    try {
      await _supabase.from('chat_messages').insert({
        'customer_email': customerEmail,
        'customer_name': customerName,
        'message': message,
        'is_from_customer': isFromCustomer,
        'is_read': false,
      });
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Send message from customer perspective
  Future<bool> sendCustomerMessage(String message) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    final customerName = currentUser.userMetadata?['full_name'] ?? 
                        currentUser.userMetadata?['name'] ?? 
                        currentUser.email?.split('@')[0] ?? 'Customer';

    print('Customer sending message: $message');
    
    final result = await sendMessage(
      customerEmail: currentUser.email!,
      customerName: customerName,
      message: message,
      isFromCustomer: true,
    );

    if (result) {
      print('Customer message sent successfully');
    } else {
      print('Failed to send customer message');
    }
    
    return result;
  }

  // Send message from admin perspective
  Future<bool> sendAdminMessage({
    required String customerEmail,
    required String customerName,
    required String message,
  }) async {
    print('Admin sending message to $customerEmail: $message');
    
    final result = await sendMessage(
      customerEmail: customerEmail,
      customerName: customerName,
      message: message,
      isFromCustomer: false,
    );

    if (result) {
      print('Admin message sent successfully');
    } else {
      print('Failed to send admin message');
    }
    
    return result;
  }

  // Mark messages as read
  Future<bool> markMessagesAsRead(String customerEmail, {bool forCustomer = false}) async {
    try {
      await _supabase.from('chat_messages').update({'is_read': true}).eq('customer_email', customerEmail).eq(
        'is_from_customer', forCustomer,
      );
      return true;
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }

  // Mark admin messages as read for customer
  Future<bool> markAdminMessagesAsRead(String customerEmail) async {
    try {
      await _supabase.from('chat_messages').update({'is_read': true}).eq('customer_email', customerEmail).eq('is_from_customer', false);
      return true;
    } catch (e) {
      print('Error marking admin messages as read: $e');
      return false;
    }
  }

  // Mark customer messages as read for admin
  Future<bool> markCustomerMessagesAsRead(String customerEmail) async {
    try {
      await _supabase.from('chat_messages').update({'is_read': true}).eq('customer_email', customerEmail).eq('is_from_customer', true);
      return true;
    } catch (e) {
      print('Error marking customer messages as read: $e');
      return false;
    }
  }

  // Get or create chat session
  Future<String?> getOrCreateChatSession(String customerEmail, String customerName) async {
    try {
      final response = await _supabase.rpc('get_or_create_chat_session', params: {
        'p_customer_email': customerEmail,
        'p_customer_name': customerName,
      });
      return response as String?;
    } catch (e) {
      print('Error creating chat session: $e');
      return null;
    }
  }

  // Get stream of unread messages for admin
  Stream<List<Map<String, dynamic>>> getUnreadMessagesStream() {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // Get unread count for a specific conversation (customer messages for admin)
  Future<int> getUnreadCountForConversation(String customerEmail) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('customer_email', customerEmail)
          .eq('is_from_customer', true)
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Get unread admin messages count for customer
  Future<int> getUnreadAdminMessagesCount(String customerEmail) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('customer_email', customerEmail)
          .eq('is_from_customer', false)
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      print('Error getting unread admin messages count: $e');
      return 0;
    }
  }

  // Get total unread count for admin
  Future<int> getTotalUnreadCount() async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('is_from_customer', true)
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }

  // Close chat session
  Future<bool> closeChatSession(String customerEmail) async {
    try {
      await _supabase
          .from('chat_sessions')
          .update({'session_status': 'closed'})
          .eq('customer_email', customerEmail);
      return true;
    } catch (e) {
      print('Error closing chat session: $e');
      return false;
    }
  }

  // Archive chat session
  Future<bool> archiveChatSession(String customerEmail) async {
    try {
      await _supabase
          .from('chat_sessions')
          .update({'session_status': 'archived'})
          .eq('customer_email', customerEmail);
      return true;
    } catch (e) {
      print('Error archiving chat session: $e');
      return false;
    }
  }

  // Get chat history for a customer
  Future<List<Map<String, dynamic>>> getChatHistory(String customerEmail) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('*')
          .eq('customer_email', customerEmail)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting chat history: $e');
      return [];
    }
  }

  // Format message time
  static String formatMessageTime(DateTime dateTime) {
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

  // Format detailed message time
  static String formatDetailedMessageTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .single();
      return response['role'] == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get customer info from email
  Future<Map<String, dynamic>?> getCustomerInfo(String customerEmail) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('email', customerEmail)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting customer info: $e');
      return null;
    }
  }

  // Delete message (admin only)
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _supabase.from('chat_messages').delete().eq('id', messageId);
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Clear all messages in a conversation (admin only)
  Future<bool> clearConversation(String customerEmail) async {
    try {
      await _supabase.from('chat_messages').delete().eq('customer_email', customerEmail);
      return true;
    } catch (e) {
      print('Error clearing conversation: $e');
      return false;
    }
  }
}
