import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/pages/staff/staff_order_history_page.dart';
import 'package:yang_chow/pages/admin/refund_management_page.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0C241F),
                Color(0xFF14332E),
                Color(0xFF1B453D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.warmGold.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1C18).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // ── Logo & Terminal Title ──
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Color(0xFFD9A441),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YANG CHOW RESTAURANT',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD9A441),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              'Staff POS Terminal',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF34C759).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const LivePulseDot(color: Color(0xFF34C759), size: 5),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ONLINE',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF86EFAC),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 8.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Prominent Visible REFUNDS Button ──
                  AnimatedTapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RefundManagementPage(isFullscreen: true, todayOnly: true),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB45309), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFDE68A).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.currency_exchange_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Refunds',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Order History Button ──
                  AnimatedTapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StaffOrderHistoryPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'History',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Staff Profile Badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD9A441), width: 1.2),
                            color: const Color(0xFF14332E),
                          ),
                          child: const Center(
                            child: Icon(Icons.person, color: Color(0xFFD9A441), size: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isLoading
                            ? const SizedBox(
                                width: 30,
                                height: 10,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white24,
                                  color: Color(0xFFD9A441),
                                ),
                              )
                            : Text(
                                _userName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Logout Button ──
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 20),
                    tooltip: 'Logout',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Row(
                            children: [
                              const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm Logout',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          content: Text(
                            'Are you sure you want to end your POS session and logout?',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await Supabase.instance.client.auth.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context, '/staff-login');
                                }
                              },
                              child: Text(
                                'Logout',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }

  // ignore: unused_element
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
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
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
      case 'stock_alert':
        return Icons.warning_amber_rounded;
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
    if (n['action_type'] == 'stock_alert') {
      return 'Stock Alert';
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
    if (n['action_type'] == 'stock_alert') {
      return n['event_type'] ?? 'Stock Alert';
    }
    if (n['action_type'] == 'pos_order') {
      return 'POS staff have order please process';
    }
    return '${n['actor_name'] ?? 'System'} ${n['action_type']} reservation for ${n['event_type'] ?? 'Event'}';
  }
}