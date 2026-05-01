import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/pages/staff/staff_order_history_page.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:intl/intl.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _userName = 'Staff';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email != null) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('firstname, lastname')
            .eq('email', user!.email!)
            .maybeSingle();

        if (userResponse != null) {
          final firstName = userResponse['firstname']?.toString() ?? '';
          final lastName = userResponse['lastname']?.toString() ?? '';
          
          // Use email prefix if firstname is "Customer" or empty, or if both names are empty
          if (firstName.isNotEmpty && lastName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = '$firstName $lastName';
            });
          } else if (firstName.isNotEmpty && firstName != 'Customer') {
            setState(() {
              _userName = firstName;
            });
          } else {
            setState(() {
              _userName = user.email!.split('@')[0];
            });
          }
        } else {
          setState(() {
            _userName = user.email!.split('@')[0];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 50,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.point_of_sale, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Staff POS System',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Current user info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                topLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: Colors.black54, size: 14),
                const SizedBox(width: 6),
                _isLoading
                    ? SizedBox(
                        width: 40,
                        height: 12,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.grey.shade600,
                        ),
                      )
                    : Text(
                        _userName,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black54),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaffOrderHistoryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.black54),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        
                        // Logout sequence
                        await Supabase.instance.client.auth.signOut();

                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/staff-login');
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getAdminNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final hasUnread = notifications.any((n) => !n['is_read']);

        return Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black54,
              ),
              onPressed: () => _showNotificationsDialog(notifications),
              tooltip: 'Notifications',
            ),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {
    NotificationService.markAllAsRead('', forAdmin: true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: notifications.isEmpty
              ? const Center(child: Text('No new activity'))
              : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final date = DateTime.parse(n['created_at']).toLocal();
                    final timeStr = DateFormat('MMM d, h:mm a').format(date);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: Icon(
                          _getIconForAction(n['action_type']),
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _getNotificationTitle(n),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getNotificationSubtitle(n),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action) {
      case 'stock_request':
        return Icons.inventory_2;
      case 'pos_order':
        return Icons.shopping_cart;
      case 'created':
        return Icons.add_circle;
      case 'cancelled':
      case 'deleted':
        return Icons.cancel;
      case 'paid':
        return Icons.payments;
      case 'updated':
        return Icons.edit;
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationTitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Stock Request';
    }
    if (n['action_type'] == 'pos_order') {
      return 'New Order';
    }
    switch (n['action_type']) {
      case 'created':
        return 'New Reservation';
      case 'cancelled':
        return 'Reservation Cancelled';
      case 'deleted':
        return 'Reservation Deleted';
      case 'paid':
        return 'Payment Received';
      case 'updated':
        return 'Reservation Modified';
      default:
        return 'Activity Alert';
    }
  }

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Kitchen has requested stock: ${n['event_type']}';
    }
    if (n['action_type'] == 'pos_order') {
      return 'POS staff have order please process';
    }
    return '${n['actor_name'] ?? 'System'} ${n['action_type']} reservation for ${n['event_type'] ?? 'Event'}';
  }
}