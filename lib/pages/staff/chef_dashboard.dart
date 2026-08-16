import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/notification_service.dart';

// ══════════════════════════════════════════════════════════
//  CHEF DASHBOARD PAGE
// ══════════════════════════════════════════════════════════
class ChefDashboardPage extends StatefulWidget {
  const ChefDashboardPage({super.key});

  @override
  State<ChefDashboardPage> createState() => _ChefDashboardPageState();
}

class _ChefDashboardPageState extends State<ChefDashboardPage>
    with TickerProviderStateMixin {
  int _currentTab = 0;
  late final PageController _pageController;

  // Notifications
  int _pendingOrderCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _orderStream;
  int _lastSeenPendingCount = 0;
  final Set<String> _dismissedNotificationIds = {};
  
  // Popup debouncing
  Timer? _popupDebounceTimer;
  Map<String, dynamic>? _pendingNotification;
  static const Duration _popupDebounceDelay = Duration(seconds: 2);
  bool _isPopupShowing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _listenForNewOrders();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orderStream?.cancel();
    _popupDebounceTimer?.cancel();
    super.dispose();
  }

  // ── Real-time new-order notifications ───────────────────
  void _listenForNewOrders() {
    // Regular orders
    _orderStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) {
          if (!mounted) return;
          _refreshPendingCount(rows, isAdvance: false);
        });

    // Advance orders
    Supabase.instance.client
        .from('advance_orders')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          if (!mounted) return;
          _refreshPendingCount(rows, isAdvance: true);
        });
  }

  int _pendingRegular = 0;
  int _pendingAdvance = 0;

  Future<void> _refreshPendingCount(List<Map<String, dynamic>> orders, {required bool isAdvance}) async {
    try {
      int pending = 0;
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      for (final o in orders) {
        final rs = o['refund_status']?.toString() ?? 'none';
        final status = o['status']?.toString().toLowerCase() ?? '';
        if (rs == 'full_refund' || status == 'refunded' || status == 'cancelled') continue;

        if (isAdvance) {
          final orderDateStr = o['order_date']?.toString();
          if (orderDateStr != null && orderDateStr.compareTo(todayStr) > 0) {
            continue; // Skip future dates
          }
        }

        final ks = o[isAdvance ? 'status' : 'kitchen_status']?.toString() ?? 'Pending';
        final ps = o['payment_status']?.toString() ?? 'unpaid';
        // For advance orders, only count if admin has approved (status becomes 'pending' after approval)
        // Skip orders still awaiting admin verification
        if (isAdvance) {
          final advStatus = o['status']?.toString().toLowerCase() ?? '';
          if (advStatus == 'awaiting_verification' || advStatus == 'unpaid') continue;
        }
        if ((ks == 'Pending' || ks == 'pending') && (ps == 'paid' || ps == 'fully_paid')) pending++;
      }

      if (!mounted) return;
      
      setState(() {
        if (isAdvance) {
          _pendingAdvance = pending;
        } else {
          _pendingRegular = pending;
        }
        _pendingOrderCount = _pendingRegular + _pendingAdvance;
      });

      final totalPending = _pendingRegular + _pendingAdvance;
      final isNew = totalPending > _lastSeenPendingCount;

      if (isNew && _currentTab != 0) {
        _lastSeenPendingCount = totalPending;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '$totalPending total pending order${totalPending == 1 ? '' : 's'} in the kitchen!',
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        _lastSeenPendingCount = totalPending;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentTab = idx),
                children: const [
                  _CombinedKitchenTab(),
                  _UpcomingEventsTab(),
                  _FinishedOrdersTab(),
                  _InventoryRequestTab(),
                  _StockViewTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ───────────────────────────────────────────────
  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B211D), Color(0xFF133831)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x440B211D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chef Badge
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFE6C374).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFE6C374), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CHEF KITCHEN DISPLAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Live Order & Inventory Dispatch',
                  style: TextStyle(
                    color: Color(0xFFE6C374),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Live status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                SizedBox(width: 5),
                Text(
                  'LIVE KDS',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Clock
          StreamBuilder<DateTime>(
            stream: Stream.periodic(
              const Duration(seconds: 1),
              (_) => DateTime.now(),
            ),
            builder: (context, snap) {
              final now = snap.data ?? DateTime.now();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(now).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('h:mm:ss a').format(now),
                      style: const TextStyle(
                        color: Color(0xFFE6C374),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildNotificationIcon(),
          const SizedBox(width: 8),
          // Logout
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _confirmLogout,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE6C374),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notifications ───────────────────────────────────────
  Widget _buildNewNotificationPopup(Map<String, dynamic> n) {
    // If popup is already showing, don't show another one
    if (_isPopupShowing) {
      return const SizedBox.shrink();
    }
    
    // Store the latest notification and cancel existing timer
    _pendingNotification = n;
    _popupDebounceTimer?.cancel();
    
    // Start new debounce timer
    _popupDebounceTimer = Timer(_popupDebounceDelay, () {
      if (_pendingNotification != null && !_isPopupShowing) {
        _showComprehensiveNotificationPopup(_pendingNotification!);
        _pendingNotification = null;
      }
    });
    
    return const SizedBox.shrink();
  }

  void _showComprehensiveNotificationPopup(Map<String, dynamic> notification) {
    final actionType = notification['action_type']?.toString() ?? '';
    
    // Set flag to prevent multiple popups
    setState(() {
      _isPopupShowing = true;
    });
    
    // Mark all unread notifications of the same type as dismissed
    _dismissAllSimilarNotifications(actionType);
    
    // Route to appropriate popup based on action type
    switch (actionType) {
      case 'stock_alert':
        _showCriticalStockAlertPopup(notification);
        break;
      case 'pos_order':
        _showNewOrderPopup(notification);
        break;
      case 'advance_order_ticket':
        final eventType = notification['event_type']?.toString() ?? '';
        if (eventType.contains('Event Reservation')) {
          _showEventReservationPopup(notification);
        } else {
          _showAdvanceOrderPopup(notification);
        }
        break;
      case 'stock_approved':
        _showStockApprovedPopup(notification);
        break;
      case 'created':
      case 'updated':
      case 'paid':
      case 'deposit_paid':
      case 'fully_paid':
      case 'balance_cleared':
        _showEventReservationPopup(notification);
        break;
      default:
        _showGenericNotificationPopup(notification);
    }
  }

  void _closePopup() {
    setState(() {
      _isPopupShowing = false;
    });
  }

  void _dismissAllSimilarNotifications(String actionType) {
    // Mark all notifications of this type as dismissed to prevent multiple popups
    // This will be called when showing a popup to dismiss all similar pending notifications
    setState(() {
      _dismissedNotificationIds.add('all_$actionType');
    });
  }

  void _showCriticalStockAlertPopup(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Critical Stock Alerts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '8 items need attention',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Out of Stock Section
                    _buildStockSection(
                      title: 'Out of Stock',
                      count: 1,
                      items: ['Pineapple Chunks'],
                      icon: Icons.block,
                      iconColor: Colors.red,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Low Stock Section
                    _buildStockSection(
                      title: 'Low Stock',
                      count: 7,
                      items: ['Patatim', 'Curry Sauce', 'Soy Sauce', 'Vinegar', 'Garlic', 'Onion', 'Cooking Oil'],
                      icon: Icons.trending_down,
                      iconColor: Colors.orange,
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                          // Navigate to Stock tab
                          _pageController.animateToPage(
                            4,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentTab = 4);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Manage Inventory',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Understood',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewOrderPopup(Map<String, dynamic> notification) {
    final eventType = notification['event_type']?.toString() ?? 'New POS Order';
    
    // Parse the event type to extract order count
    String title = 'New POS Order';
    String message = 'POS staff have placed a new order. Please process it immediately.';
    
    if (eventType.contains('new POS orders')) {
      // Format: "X new POS orders"
      final regex = RegExp(r'(\d+)\s+new\s+POS\s+orders');
      final match = regex.firstMatch(eventType);
      if (match != null) {
        final count = match.group(1) ?? '1';
        title = 'New POS Orders';
        message = '$count new order${count == '1' ? '' : 's'} have been placed. Please process them immediately.';
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check the Kitchen tab for order details',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                          // Navigate to Kitchen tab
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentTab = 0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Orders',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvanceOrderPopup(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Purple Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Advance Order Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'An advance order is now ready for preparation.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check the Kitchen tab for order details',
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                          // Navigate to Kitchen tab
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentTab = 0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Orders',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockApprovedPopup(Map<String, dynamic> notification) {
    final eventType = notification['event_type']?.toString() ?? 'Stock Approved';
    
    // Parse the event type to extract item count
    String itemCount = '1';
    String message = 'Your stock request has been approved by admin.';
    
    if (eventType.contains('Stock Approved:')) {
      // Format: "Stock Approved: X items" or "Stock Approved: Item Name (quantity unit)"
      final regex = RegExp(r'Stock Approved:\s*(\d+)\s+items?');
      final match = regex.firstMatch(eventType);
      if (match != null) {
        itemCount = match.group(1) ?? '1';
        message = '$itemCount item${itemCount == '1' ? '' : 's'} have been approved and added to your inventory.';
      } else {
        // Single item format: "Stock Approved: Item Name (quantity unit)"
        message = 'Stock has been added to your inventory.';
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Stock Request Approved',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check your inventory for updated stock levels',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                          // Navigate to Stock tab
                          _pageController.animateToPage(
                            4,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentTab = 4);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Inventory',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventReservationPopup(Map<String, dynamic> notification) {
    final title = _getNotificationTitle(notification);
    final subtitle = _getNotificationSubtitle(notification);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Orange Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check the Events tab for details',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
                          _closePopup();
                          // Navigate to Events tab
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          setState(() => _currentTab = 1);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Events',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenericNotificationPopup(Map<String, dynamic> notification) {
    final title = _getNotificationTitle(notification);
    final subtitle = _getNotificationSubtitle(notification);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gray Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dismissedNotificationIds.add(notification['id'].toString());
                        });
                        Navigator.pop(context);
_closePopup();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dismissedNotificationIds.add(notification['id'].toString());
                          });
                          Navigator.pop(context);
_closePopup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockSection({
    required String title,
    required int count,
    required List<String> items,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title ($count)',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Text(
              '• $item',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ── Notifications ───────────────────────────────────────
  Widget _buildNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getKitchenNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadNotifications = notifications.where((n) => !n['is_read']).toList();
        final hasUnread = unreadNotifications.isNotEmpty;

        Map<String, dynamic>? latestUnread;
        if (hasUnread) {
          latestUnread = unreadNotifications.first;
        }

        final showPopup = latestUnread != null &&
            !_dismissedNotificationIds.contains(latestUnread['id'].toString());

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPopup) ...[
              _buildNewNotificationPopup(latestUnread),
              const SizedBox(width: 8),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (latestUnread != null) {
                      setState(() {
                        _dismissedNotificationIds.add(latestUnread!['id'].toString());
                      });
                    }
                    _showNotificationsDialog(notifications);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
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
      case 'advance_order_ticket':
        return Icons.assignment;
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
    if (n['action_type'] == 'advance_order_ticket') {
      final eventType = n['event_type']?.toString() ?? '';
      if (eventType.contains('Event Reservation')) {
        return 'Event Reservation Approved';
      }
      return 'New Advance Order';
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
    if (n['action_type'] == 'advance_order_ticket') {
      final eventType = n['event_type']?.toString() ?? '';
      if (eventType.contains('Event Reservation')) {
        return 'An event reservation menu ticket has been approved by admin.';
      }
      return 'An advance order menu ticket has been approved by admin.';
    }
    return '${n['actor_name'] ?? 'System'} ${n['action_type']} reservation for ${n['event_type'] ?? 'Event'}';
  }

  // ── Bottom Navigation ────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (Icons.restaurant_rounded, 'Kitchen'),
      (Icons.event_note_rounded, 'Events'),
      (Icons.check_circle_outline_rounded, 'Finished'),
      (Icons.inventory_2_outlined, 'Requests'),
      (Icons.fact_check_rounded, 'Stock'),
    ];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B211D), Color(0xFF133831)],
        ),
        border: Border(top: BorderSide(color: Color(0x33E6C374), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x440B211D),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _currentTab == i;
          final (icon, label) = items[i];
          final hasBadge = (i == 0 && _pendingOrderCount > 0);
          final badgeCount = _pendingOrderCount;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
                setState(() => _currentTab = i);
              },
              child: Container(
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFE6C374).withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: selected ? Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.4)) : null,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icon,
                            color: selected ? const Color(0xFFE6C374) : Colors.white60,
                            size: 19,
                          ),
                          if (hasBadge)
                            Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Text(
                                  '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? const Color(0xFFE6C374) : Colors.white60,
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Logout ──────────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: Color(0xFF1E293B))),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/staff-login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 1 — COMBINED KITCHEN ORDERS (POS + Advance)
// ══════════════════════════════════════════════════════════
class _CombinedKitchenTab extends StatefulWidget {
  const _CombinedKitchenTab();

  @override
  State<_CombinedKitchenTab> createState() => _CombinedKitchenTabState();
}

class _CombinedKitchenTabState extends State<_CombinedKitchenTab> {
  final Map<String, String> _kitchenStatus = {};

  static const _statusOrder = ['Pending', 'Preparing', 'Ready', 'Done'];
  static const _statusColors = {
    'Pending': Color(0xFFFFA726),
    'Preparing': Color(0xFF2196F3),
    'Ready': Color(0xFF4CAF50),
    'Done': Color(0xFF9E9E9E),
  };

  // Stream subscriptions instead of StreamBuilders
  StreamSubscription<List<Map<String, dynamic>>>? _posSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _advSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _resSubscription;
  List<Map<String, dynamic>> _posRaw = [];
  List<Map<String, dynamic>> _advRaw = [];
  List<Map<String, dynamic>> _resRaw = [];
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToStreams();
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _advSubscription?.cancel();
    _resSubscription?.cancel();
    super.dispose();
  }

  void _listenToStreams() {
    _posSubscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _posRaw = rows;
            _initialLoading = false;
            // Sync local cache for NEW orders only
            for (final o in rows) {
              final key = 'pos_${o['id']}';
              if (!_kitchenStatus.containsKey(key)) {
                _kitchenStatus[key] = o['kitchen_status']?.toString() ?? 'Pending';
              }
            }
          });
        });

    _advSubscription = Supabase.instance.client
        .from('advance_orders')
        .stream(primaryKey: ['id'])
        .order('order_date', ascending: true)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _advRaw = rows;
            _initialLoading = false;
            // Sync local cache for NEW orders only
            for (final o in rows) {
              final key = 'adv_${o['id']}';
              if (!_kitchenStatus.containsKey(key)) {
                final status = o['status']?.toString().toLowerCase();
                _kitchenStatus[key] = status == 'preparing' ? 'Preparing' :
                                      status == 'ready' ? 'Ready' :
                                      status == 'done' ? 'Done' : 'Pending';
              }
            }
          });
        });

    _resSubscription = Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _resRaw = rows;
            _initialLoading = false;
            // Sync local cache for NEW reservations only
            for (final o in rows) {
              final key = 'res_${o['id']}';
              if (!_kitchenStatus.containsKey(key)) {
                _kitchenStatus[key] = o['kitchen_status']?.toString() ?? 'Pending';
              }
            }
          });
        });
  }

  // ── Update status for POS orders ──
  Future<void> _updatePosStatus(String orderId, String newStatus) async {
    setState(() => _kitchenStatus['pos_$orderId'] = newStatus);
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'kitchen_status': newStatus})
          .eq('id', orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Update status for Advance orders ──
  Future<void> _updateAdvanceStatus(String orderId, String newStatus) async {
    setState(() => _kitchenStatus['adv_$orderId'] = newStatus);
    try {
      await Supabase.instance.client
          .from('advance_orders')
          .update({'status': newStatus.toLowerCase()})
          .eq('id', orderId);

      if (newStatus == 'Ready' || newStatus == 'Done') {
        try {
          final orderData = await Supabase.instance.client
              .from('advance_orders')
              .select('customer_email, order_type, id')
              .eq('id', orderId)
              .single();
          
          if (orderData['customer_email'] != null) {
            await NotificationService.sendNotification(
              recipientEmail: orderData['customer_email'],
              actorName: 'Kitchen',
              actionType: newStatus.toLowerCase(),
              reservationId: orderId,
              eventType: 'Advance Order (${orderData['order_type']})',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Update status for Event reservations ──
  Future<void> _updateReservationStatus(String resId, String newStatus) async {
    setState(() => _kitchenStatus['res_$resId'] = newStatus);
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'kitchen_status': newStatus})
          .eq('id', resId);

      if (newStatus == 'Ready' || newStatus == 'Done') {
        try {
          final resData = await Supabase.instance.client
              .from('reservations')
              .select('customer_email, event_type, id')
              .eq('id', resId)
              .single();
          
          if (resData['customer_email'] != null) {
            await NotificationService.sendNotification(
              recipientEmail: resData['customer_email'],
              actorName: 'Kitchen',
              actionType: newStatus.toLowerCase(),
              reservationId: resId,
              eventType: 'Event Reservation (${resData['event_type']})',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> _buildOrdersList() {
    // ── Process POS orders ──
    final posOrders = _posRaw.where((o) {
      final ks = _kitchenStatus['pos_${o['id']}'] ?? 'Pending';
      final ps = o['payment_status']?.toString() ?? 'unpaid';
      final rs = o['refund_status']?.toString() ?? 'none';
      final status = o['status']?.toString().toLowerCase() ?? '';

      final isRefunded = rs == 'full_refund' || status == 'refunded' || status == 'cancelled';

      return !isRefunded && ks != 'Done' && ks != 'Ready' && (ps == 'paid' || ps == 'fully_paid');
    }).map((o) => {
      ...o,
      '_is_advance': false,
      '_is_reservation': false,
      '_sort_key': o['created_at']?.toString() ?? '',
    }).toList();

    // ── Process Advance orders ──
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final advOrders = _advRaw.map((o) {
      final key = 'adv_${o['id']}';
      final status = o['status']?.toString().toLowerCase();
      final mappedStatus = status == 'preparing' ? 'Preparing' :
                           status == 'ready' ? 'Ready' :
                           status == 'done' ? 'Done' : 'Pending';
      return {
        ...o,
        '_is_advance': true,
        '_is_reservation': false,
        'kitchen_status': _kitchenStatus[key] ?? mappedStatus,
        '_sort_key': o['created_at']?.toString() ?? '',
      };
    }).where((o) {
      final orderDateStr = o['order_date']?.toString();
      if (orderDateStr != null && orderDateStr.compareTo(todayStr) > 0) {
        return false;
      }

      final ks = o['kitchen_status'];
      final ps = o['payment_status']?.toString().toLowerCase();
      final rs = o['refund_status']?.toString() ?? 'none';
      final status = o['status']?.toString().toLowerCase();

      final isRefunded = rs == 'full_refund' || status == 'refunded' || status == 'cancelled';
      final isApprovedAdvance = status == 'pending' || status == 'preparing' || status == 'ready';

      return !isRefunded && ks != 'Done' && ks != 'Ready' && (ps == 'paid' || ps == 'fully_paid') && isApprovedAdvance;
    }).toList();

    // ── Process Event reservations for today ──
    final resOrders = _resRaw.where((o) {
      final isMenuBased = o['is_menu_based'] == true;
      final ps = o['payment_status']?.toString().toLowerCase();
      final rs = o['refund_status']?.toString() ?? 'none';
      final isPaid = ps == 'paid' || ps == 'fully_paid';
      
      final eventDateStr = o['event_date']?.toString();
      final isTodayOrPast = eventDateStr != null && eventDateStr.compareTo(todayStr) <= 0;
      
      final resStatus = o['status']?.toString().toLowerCase();
      final isRefunded = rs == 'full_refund' || resStatus == 'refunded' || resStatus == 'cancelled';
      final isApproved = resStatus == 'confirmed' || resStatus == 'completed';
      
      final ks = _kitchenStatus['res_${o['id']}'] ?? o['kitchen_status']?.toString() ?? 'Pending';
      return !isRefunded && isMenuBased && isPaid && isTodayOrPast && isApproved && ks != 'Done' && ks != 'Ready';
    }).map((o) => {
      ...o,
      '_is_advance': false,
      '_is_reservation': true,
      'kitchen_status': _kitchenStatus['res_${o['id']}'] ?? o['kitchen_status']?.toString() ?? 'Pending',
      '_sort_key': '${o['event_date']} ${o['start_time']}',
    }).toList();

    // ── Combine and sort by creation time ──
    final List<Map<String, dynamic>> allOrders = [...posOrders, ...advOrders, ...resOrders];
    allOrders.sort((a, b) {
      final aTime = DateTime.tryParse(a['_sort_key']?.toString() ?? '') ?? DateTime(0);
      final bTime = DateTime.tryParse(b['_sort_key']?.toString() ?? '') ?? DateTime(0);
      return aTime.compareTo(bTime);
    });
    return allOrders;
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    final allOrders = _buildOrdersList();

    if (allOrders.isEmpty) {
      return _buildEmptyState(Icons.restaurant, 'Kitchen Clear', 'No active orders at the moment.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth < 900 ? 3 : (constraints.maxWidth < 1100 ? 4 : 5));
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: allOrders.length,
          itemBuilder: (_, i) {
            final o = allOrders[i];
            final id = o['id'].toString();
            final isAdvance = o['_is_advance'] == true;
            final isReservation = o['_is_reservation'] == true;
            final statusKey = isReservation ? 'res_$id' : (isAdvance ? 'adv_$id' : 'pos_$id');

            return FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 330,
                height: 330 / 1.05,
                child: _KitchenOrderCard(
                  order: o,
                  kitchenStatus: isReservation
                      ? (_kitchenStatus[statusKey] ?? 'Pending')
                      : (isAdvance
                          ? (o['kitchen_status'] ?? 'Pending')
                          : (_kitchenStatus[statusKey] ?? 'Pending')),
                  onStatusChanged: isReservation
                      ? (ns) => _updateReservationStatus(id, ns)
                      : (isAdvance
                          ? (ns) => _updateAdvanceStatus(id, ns)
                          : (ns) => _updatePosStatus(id, ns)),
                  statusOrder: _statusOrder,
                  statusColors: _statusColors,
                  isAdvanceOrder: isAdvance,
                  isReservation: isReservation,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Order Card ───────────────────────────────────────────
class _KitchenOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String kitchenStatus;
  final ValueChanged<String> onStatusChanged;
  final List<String> statusOrder;
  final Map<String, Color> statusColors;
  final bool isAdvanceOrder;
  final bool isReservation;

  const _KitchenOrderCard({
    required this.order,
    required this.kitchenStatus,
    required this.onStatusChanged,
    required this.statusOrder,
    required this.statusColors,
    required this.isAdvanceOrder,
    this.isReservation = false,
  });

  @override
  State<_KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<_KitchenOrderCard> {
  List<Map<String, dynamic>> _items = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadItems();
    // Refresh every second so "Just now" → "X min ago" transitions automatically
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _KitchenOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['refund_status'] != widget.order['refund_status'] ||
        oldWidget.order['total_amount'] != widget.order['total_amount']) {
      _loadItems();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (widget.isAdvanceOrder || widget.isReservation) {
      // For advance orders and reservations, items are in selected_menu_items JSON column
      final selectedItems = widget.order['selected_menu_items'] as Map<String, dynamic>? ?? {};
      final List<Map<String, dynamic>> items = [];
      selectedItems.forEach((name, qty) {
        items.add({
          'item_name': name,
          'quantity': qty,
        });
      });
      if (mounted) {
        setState(() => _items = items);
      }
    } else {
      try {
        final rows = await Supabase.instance.client
            .from('order_items')
            .select('item_name, quantity, unit_price')
            .eq('order_id', widget.order['id'].toString());
        if (mounted) {
          setState(() => _items = List<Map<String, dynamic>>.from(rows));
        }
      } catch (_) {}
    }
  }

  void _showPrepTimeRestrictedDialog(BuildContext context, DateTime prepTime) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            const Text(
              'Order is Locked',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is an Advance Order. Kitchen is only allowed to start preparing this order starting 20 minutes before the scheduled time.',
              style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scheduled Order:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.order['order_date']} at ${widget.order['order_time']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start Preparing At:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMMM d, yyyy - hh:mm a').format(prepTime),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.kitchenStatus;
    final customer = widget.order['customer_name']?.toString() ?? 'Guest';
    final createdAt = widget.order['created_at'] != null
        ? DateTime.tryParse(widget.order['created_at'].toString())
        : null;
    final elapsed = createdAt != null
        ? DateTime.now().difference(createdAt.toLocal())
        : null;
    String formatElapsed(Duration elapsed) {
      if (elapsed.inMinutes < 1) {
        return 'Just now';
      } else if (elapsed.inMinutes < 60) {
        final minutes = elapsed.inMinutes;
        return minutes == 1 ? '1 min ago' : '$minutes mins ago';
      } else if (elapsed.inHours < 24) {
        final hours = elapsed.inHours;
        return hours == 1 ? '1 hour ago' : '$hours hours ago';
      } else {
        final days = elapsed.inDays;
        return days == 1 ? '1 day ago' : '$days days ago';
      }
    }

    final elapsedStr = elapsed != null ? formatElapsed(elapsed) : '';

    final currentIdx = widget.statusOrder.indexOf(status);
    final nextStatus = currentIdx < widget.statusOrder.length - 1
        ? widget.statusOrder[currentIdx + 1]
        : null;

    final prepTime = widget.isAdvanceOrder
        ? _getPrepareByDateTime(
            widget.order['order_date']?.toString(),
            widget.order['order_time']?.toString(),
          )
        : null;
    final isTooEarly = prepTime != null && DateTime.now().isBefore(prepTime) && status == 'Pending';

    final isUrgent =
        elapsed != null && elapsed.inMinutes >= 15 && status == 'Pending';

  void showOrderDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Container(
              width: size.width * 0.45,
              height: size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.statusColors[widget.kitchenStatus]?.withValues(alpha: 0.08) ?? Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.isReservation
                                    ? 'EVENT RESERVATION'
                                    : (widget.isAdvanceOrder ? 'ADVANCE ORDER' : 'Order ${_formatOrderId(widget.order)}'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: (widget.isAdvanceOrder || widget.isReservation) ? AppTheme.primaryColor : const Color(0xFF1E293B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (widget.isAdvanceOrder)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scheduled: ${widget.order['order_date']} at ${widget.order['order_time']}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.alarm, size: 12, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Prepare by: ${_calcPrepareTime(widget.order['order_time']?.toString())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (widget.isReservation)
                                Text(
                                  'Event: ${widget.order['event_type'] ?? ''} on ${widget.order['event_date']} at ${widget.order['start_time'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if ((widget.isAdvanceOrder && widget.order['preparation_notes'] != null && widget.order['preparation_notes'].toString().isNotEmpty) ||
                      (widget.isReservation && widget.order['special_requests'] != null && widget.order['special_requests'].toString().isNotEmpty))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_alt_outlined, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 6),
                              Text(
                                'SPECIAL NOTES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.orange.shade800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.order['preparation_notes'],
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFE5E7EB)),
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'x${item['quantity'] ?? 1}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['item_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

    final isPreparing = status == 'Preparing';
    final isReady = status == 'Ready';
    final isDone = status == 'Done';

    // Header gradient based on urgency & status
    final List<Color> headerGradient = isUrgent
        ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
        : isPreparing
            ? [const Color(0xFF0369A1), const Color(0xFF0284C7)]
            : isReady
                ? [const Color(0xFF047857), const Color(0xFF059669)]
                : isDone
                    ? [const Color(0xFF334155), const Color(0xFF475569)]
                    : [const Color(0xFF0F2C27), const Color(0xFF1E3A34)];

    final Color statusAccentColor = isUrgent
        ? const Color(0xFFEF4444)
        : isPreparing
            ? const Color(0xFF38BDF8)
            : isReady
                ? const Color(0xFF34D399)
                : const Color(0xFFE6C374);

    return GestureDetector(
      onTap: () => showOrderDetails(context),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFEF4444)
                : isPreparing
                    ? const Color(0xFF0284C7).withValues(alpha: 0.6)
                    : const Color(0xFFE2E8F0),
            width: isUrgent ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isUrgent
                  ? const Color(0x33EF4444)
                  : const Color(0x140F2C27),
              blurRadius: isUrgent ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Realistic KDS Ticket Header ─────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: headerGradient,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: statusAccentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Bold Order ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6C374),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          _formatOrderId(widget.order),
                          style: const TextStyle(
                            color: Color(0xFF0B211D),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Customer name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              widget.isAdvanceOrder
                                  ? 'Advance Order • ${widget.order['order_type'] ?? 'Take-out'}'
                                  : (widget.order['table_number']?.toString().isNotEmpty == true
                                      ? 'Dine In • Table ${widget.order['table_number']}'
                                      : 'Order Slip'),
                              style: const TextStyle(
                                color: Color(0xFFE6C374),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timer / Urgent pulse badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? const Color(0xFFFF4444)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUrgent
                                ? Colors.white
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUrgent ? Icons.local_fire_department : Icons.timer_outlined,
                              size: 11,
                              color: isUrgent ? Colors.white : Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              elapsedStr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: isUrgent ? FontWeight.w900 : FontWeight.w600,
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

            // ── Prepare By Banner (Advance Orders only) ───
            if (widget.isAdvanceOrder) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFBEB),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFDE68A)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    const Text(
                      'PREPARE BY: ',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _calcPrepareTime(widget.order['order_time']?.toString()),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Items List (Realistic Kitchen Slip) ───────
            Expanded(
              child: Container(
                color: const Color(0xFFFAFAFA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Loading items…',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        )
                      else
                        ..._items.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Qty pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2C27).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFF0F2C27).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '${item['quantity']}×',
                                    style: const TextStyle(
                                      color: Color(0xFF0F2C27),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['item_name']?.toString() ?? '—',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Order Special Note
                      if ((widget.order['note']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFFD97706),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.order['note'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Action Buttons & Ticket Footer ───────────
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  if (nextStatus != null)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: isTooEarly
                              ? () => _showPrepTimeRestrictedDialog(context, prepTime)
                              : () => widget.onStatusChanged(nextStatus),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTooEarly
                                ? const Color(0xFFE2E8F0)
                                : nextStatus == 'Preparing'
                                    ? const Color(0xFF0284C7)
                                    : nextStatus == 'Ready'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF10B981),
                            foregroundColor: isTooEarly
                                ? const Color(0xFF94A3B8)
                                : Colors.white,
                            elevation: isTooEarly ? 0 : 2,
                            shadowColor: const Color(0x33000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            isTooEarly ? Icons.lock_outline_rounded : _nextStatusIcon(nextStatus),
                            size: 16,
                          ),
                          label: Text(
                            isTooEarly
                                ? 'LOCKED (TOO EARLY)'
                                : nextStatus == 'Preparing'
                                    ? 'START PREP'
                                    : nextStatus == 'Ready'
                                        ? 'MARK READY'
                                        : 'SERVE ORDER',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (currentIdx > 0) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 38,
                      width: 40,
                      child: OutlinedButton(
                        onPressed: () => widget.onStatusChanged(
                          widget.statusOrder[currentIdx - 1],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.undo_rounded, size: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _nextStatusIcon(String status) {
    switch (status) {
      case 'Preparing':
        return Icons.local_fire_department_rounded;
      case 'Ready':
        return Icons.check_circle_outline_rounded;
      case 'Done':
        return Icons.task_alt_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }
}


// ══════════════════════════════════════════════════════════
//  TAB 2 — UPCOMING EVENTS (Future Event Reservations)
// ══════════════════════════════════════════════════════════
class _UpcomingEventsTab extends StatefulWidget {
  const _UpcomingEventsTab();

  @override
  State<_UpcomingEventsTab> createState() => _UpcomingEventsTabState();
}

class _UpcomingEventsTabState extends State<_UpcomingEventsTab> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub = Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .order('event_date', ascending: true)
        .listen((rows) {
          if (!mounted) return;
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final filtered = rows.where((r) {
            final isMenuBased = r['is_menu_based'] == true;
            final ps = r['payment_status']?.toString().toLowerCase();
            final isPaid = ps == 'paid' || ps == 'deposit_paid' || ps == 'fully_paid';
            final eventDateStr = r['event_date']?.toString();
            final isFuture = eventDateStr != null && eventDateStr.compareTo(todayStr) > 0;
            final menuItems = r['selected_menu_items'];
            final hasMenu = menuItems != null && (menuItems as Map).isNotEmpty;
            final isNotServed = r['kitchen_status']?.toString() != 'Done';
            // Only show events that have been approved by admin in Payment Approvals
            final status = r['status']?.toString().toLowerCase();
            final isApproved = status == 'confirmed' || status == 'completed';
            return isMenuBased && isPaid && isFuture && hasMenu && isNotServed && isApproved;
          }).toList();
          setState(() {
            _events = filtered;
            _loading = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_events.isEmpty) {
      return _buildEmptyState(
        Icons.calendar_month_rounded,
        'No Upcoming Events',
        'No approved event reservations with menu selections found.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Determine grid column count based on available screen width
        int crossAxisCount = 1;
        if (width >= 1280) {
          crossAxisCount = 3;
        } else if (width >= 800) {
          crossAxisCount = 2;
        }

        if (crossAxisCount > 1) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 320, // fixed height per card for uniform grid
            ),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              return _UpcomingEventCard(event: _events[index]);
            },
          );
        }

        // Single column view for mobile/narrow screens
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _UpcomingEventCard(event: _events[index]),
            );
          },
        );
      },
    );
  }
}

// ── Upcoming Event Card ───────────────────────────────────
class _UpcomingEventCard extends StatefulWidget {
  final Map<String, dynamic> event;

  const _UpcomingEventCard({required this.event});

  @override
  State<_UpcomingEventCard> createState() => _UpcomingEventCardState();
}

class _UpcomingEventCardState extends State<_UpcomingEventCard> {
  bool _isLoading = false;
  late String _kitchenStatus;

  @override
  void initState() {
    super.initState();
    _kitchenStatus = widget.event['kitchen_status']?.toString() ?? 'Pending';
  }

  Future<void> _advanceStatus() async {
    final nextStatus = _kitchenStatus == 'Ready' ? 'Done' : 'Ready';
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'kitchen_status': nextStatus})
          .eq('id', widget.event['id']);
      if (mounted) setState(() => _kitchenStatus = nextStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.event['customer_name']?.toString() ?? 'Guest';
    final eventType = widget.event['event_type']?.toString() ?? 'Event';
    final eventDateStr = widget.event['event_date']?.toString() ?? '';
    final startTime = widget.event['start_time']?.toString() ?? '';
    final guestCount = widget.event['number_of_guests'];
    final menuItems = widget.event['selected_menu_items'] as Map<String, dynamic>? ?? {};
    final specialRequests = widget.event['special_requests']?.toString() ?? '';

    // Parse event date
    String formattedDate = eventDateStr;
    int daysUntil = 0;
    try {
      final eventDate = DateTime.parse(eventDateStr);
      formattedDate = DateFormat('EEE, MMM d, yyyy').format(eventDate);
      daysUntil = eventDate.difference(DateTime.now()).inDays + 1;
    } catch (_) {}

    // Format time
    String formattedTime = startTime;
    try {
      final parts = startTime.split(':');
      if (parts.length >= 2) {
        final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        formattedTime = DateFormat('h:mm a').format(dt);
      }
    } catch (_) {}

    // Urgency styling
    Color urgencyBg;
    Color urgencyTextColor;
    String urgencyLabel;
    if (daysUntil <= 1) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyTextColor = const Color(0xFFDC2626);
      urgencyLabel = 'Tomorrow!';
    } else if (daysUntil <= 3) {
      urgencyBg = const Color(0xFFFFEDD5);
      urgencyTextColor = const Color(0xFFEA580C);
      urgencyLabel = 'In $daysUntil days';
    } else if (daysUntil <= 7) {
      urgencyBg = const Color(0xFFFEF9C3);
      urgencyTextColor = const Color(0xFFCA8A04);
      urgencyLabel = 'In $daysUntil days';
    } else {
      urgencyBg = const Color(0xFFDCFCE7);
      urgencyTextColor = const Color(0xFF16A34A);
      urgencyLabel = 'In $daysUntil days';
    }

    final isDone = _kitchenStatus == 'Done';
    final isReady = _kitchenStatus == 'Ready';

    // Check if today is the event day (or later) — button only enabled on/after event date
    bool isEventDay = false;
    try {
      final eventDate = DateTime.parse(eventDateStr);
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
      isEventDay = todayDate.compareTo(eventDateOnly) >= 0;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? const Color(0xFF86EFAC)
              : isReady
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE2E8F0),
          width: (isDone || isReady) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card Section ──────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                // Calendar Date Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(DateTime.tryParse(eventDateStr) ?? DateTime.now()).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(DateTime.tryParse(eventDateStr) ?? DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Event & Customer Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              eventType,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          if (guestCount != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $guestCount guests',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Urgency Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    urgencyLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: urgencyTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body Content ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time info row
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '$formattedDate at $formattedTime',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Menu Selection Header
                  const Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'MENU SELECTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Menu Items Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: menuItems.entries.map((entry) {
                      final qty = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$qty×',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  // Special Requests
                  if (specialRequests.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              specialRequests,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Footer Action Area ───────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                // Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFDCFCE7)
                        : (isReady ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle
                            : (isReady ? Icons.outdoor_grill : Icons.timer_outlined),
                        size: 13,
                        color: isDone
                            ? const Color(0xFF16A34A)
                            : (isReady ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _kitchenStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF16A34A)
                              : (isReady ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Compact Action Button
                if (!isDone)
                  Tooltip(
                    message: !isEventDay ? 'Available on the event date (${formattedDate})' : '',
                    child: ElevatedButton.icon(
                      onPressed: (!isEventDay || _isLoading) ? null : _advanceStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isEventDay
                            ? const Color(0xFF94A3B8)
                            : (isReady ? const Color(0xFF2563EB) : const Color(0xFF16A34A)),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              !isEventDay
                                  ? Icons.lock_clock
                                  : (isReady ? Icons.check_circle_outline : Icons.done_all_rounded),
                              size: 15,
                            ),
                      label: Text(
                        !isEventDay
                            ? 'Mark as Ready'
                            : (isReady ? 'Mark as Served' : 'Mark as Ready'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Served',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ══════════════════════════════════════════════════════════
//  TAB 3 — FINISHED ORDERS
// ══════════════════════════════════════════════════════════
class _FinishedOrdersTab extends StatefulWidget {
  const _FinishedOrdersTab();

  @override
  State<_FinishedOrdersTab> createState() => _FinishedOrdersTabState();
}

class _FinishedOrdersTabState extends State<_FinishedOrdersTab> {
  int _currentPage = 1;
  static const int _itemsPerPage = 50;
  int _selectedFilter = 0; // 0: All, 1: Regular, 2: Advance, 3: Events
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  
  final List<String> _filterLabels = ['All', 'Regular', 'Advance', 'Events'];

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchDoneOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchDoneOrders() async {
    final List<Map<String, dynamic>> result = [];

    // 1. Fetch regular POS orders
    try {
      final ordersRaw = await Supabase.instance.client
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      for (final o in ordersRaw) {
        final ks = o['kitchen_status']?.toString() ?? '';
        final rs = o['refund_status']?.toString() ?? 'none';
        final st = o['status']?.toString().toLowerCase() ?? '';

        final isDone = ks == 'Ready' ||
            ks == 'Done' ||
            rs == 'full_refund' ||
            rs == 'partial_refund' ||
            st == 'refunded' ||
            st == 'cancelled';

        if (isDone) {
          result.add({
            ...o,
            '_is_advance': false,
            '_is_reservation': false,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching POS finished orders: $e');
    }

    // 2. Fetch advance orders
    try {
      final advRaw = await Supabase.instance.client
          .from('advance_orders')
          .select()
          .order('created_at', ascending: false);

      for (final o in advRaw) {
        final st = o['status']?.toString().toLowerCase() ?? '';
        final rs = o['refund_status']?.toString() ?? 'none';

        final isDone = st == 'ready' ||
            st == 'done' ||
            st == 'cancelled' ||
            st == 'refunded' ||
            rs == 'full_refund' ||
            rs == 'partial_refund';

        if (isDone) {
          result.add({
            ...o,
            '_is_advance': true,
            '_is_reservation': false,
            'kitchen_status': st == 'ready' ? 'Ready' : 'Done',
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching advance finished orders: $e');
    }

    // 3. Fetch event reservations
    try {
      final resRaw = await Supabase.instance.client
          .from('reservations')
          .select()
          .eq('is_menu_based', true)
          .order('event_date', ascending: false);

      for (final r in resRaw) {
        final ks = r['kitchen_status']?.toString() ?? '';
        final st = r['status']?.toString().toLowerCase() ?? '';
        final rs = r['refund_status']?.toString() ?? 'none';

        final isDone = ks == 'Done' ||
            st == 'cancelled' ||
            st == 'refunded' ||
            rs == 'completed' ||
            rs == 'full_refund' ||
            rs == 'partial_refund';

        if (isDone) {
          result.add({
            ...r,
            '_is_advance': false,
            '_is_reservation': true,
            'kitchen_status': 'Done',
            'customer_name': r['customer_name'],
            'created_at': r['event_date'],
            'total_price': 0.0,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reservation finished orders: $e');
    }

    // Sort by creation time descending
    result.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final bTime =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return result;
  }

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> allOrders) {
    switch (_selectedFilter) {
      case 1: // Regular
        return allOrders.where((o) => o['_is_reservation'] != true && o['_is_advance'] != true).toList();
      case 2: // Advance
        return allOrders.where((o) => o['_is_advance'] == true).toList();
      case 3: // Events
        return allOrders.where((o) => o['_is_reservation'] == true).toList();
      default: // All
        return allOrders;
    }
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        final allOrders = snap.data ?? [];
        final filteredOrders = _filterOrders(allOrders);
        
        if (allOrders.isEmpty) {
          return _buildEmptyState(
            Icons.hourglass_empty,
            'No finished orders yet',
            '',
          );
        }

        if (filteredOrders.isEmpty) {
          return _buildEmptyState(
            Icons.filter_list_off,
            'No ${_filterLabels[_selectedFilter]} orders',
            'Try selecting a different filter.',
          );
        }

        final int totalPages = (filteredOrders.length / _itemsPerPage).ceil();
        if (_currentPage > totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentPage = totalPages);
          });
        }

        final int startIndex = (_currentPage - 1) * _itemsPerPage;
        int endIndex = startIndex + _itemsPerPage;
        if (endIndex > filteredOrders.length) endIndex = filteredOrders.length;

        final currentOrders = (startIndex < filteredOrders.length)
            ? filteredOrders.sublist(startIndex, endIndex)
            : <Map<String, dynamic>>[];

        // Count per filter
        final counts = [
          allOrders.length,
          allOrders.where((o) => o['_is_reservation'] != true && o['_is_advance'] != true).length,
          allOrders.where((o) => o['_is_advance'] == true).length,
          allOrders.where((o) => o['_is_reservation'] == true).length,
        ];
        final filterIcons = [Icons.list_alt_rounded, Icons.receipt_long_rounded, Icons.schedule_rounded, Icons.celebration_rounded];

        return Column(
          children: [
            // ── Premium Filter Tab Bar ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B211D), Color(0xFF133831)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: List.generate(_filterLabels.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _selectedFilter = index; _currentPage = 1; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE6C374) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFE6C374) : Colors.white.withValues(alpha: 0.10),
                            width: 1.2,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFFE6C374).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              filterIcons[index],
                              size: 16,
                              color: isSelected ? const Color(0xFF0B211D) : Colors.white.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _filterLabels[index],
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0B211D) : Colors.white.withValues(alpha: 0.70),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${counts[index]}',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0B211D) : Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // ── Dark Column Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2D2A),
              ),
              child: Row(
                children: const [
                  SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text('ORDER', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontSize: 10, letterSpacing: 1.2)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('DETAILS', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontSize: 10, letterSpacing: 1.2)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontSize: 10, letterSpacing: 1.2)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontSize: 10, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF1F4F3),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: currentOrders.length,
                  itemBuilder: (_, i) => _FinishedOrderCard(order: currentOrders[i]),
                ),
              ),
            ),
            if (totalPages > 1) _buildPagination(totalPages),
          ],
        );
      },
    );
  }

  Widget _buildPagination(int totalPages) {
    List<Widget> pageWidgets = [];
    bool lastWasEllipsis = false;

    // Show more numbers: current +/- 2
    for (int i = 1; i <= totalPages; i++) {
      if (totalPages <= 7 || i == 1 || i == totalPages || (i >= _currentPage - 2 && i <= _currentPage + 2)) {
        final isSelected = i == _currentPage;
        pageWidgets.add(
          GestureDetector(
            onTap: () => setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$i',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
        lastWasEllipsis = false;
      } else {
        if (!lastWasEllipsis) {
          pageWidgets.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 16)),
          ));
          lastWasEllipsis = true;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prev button
          _buildNavButton(
            label: 'PREV',
            icon: Icons.chevron_left_rounded,
            isEnabled: _currentPage > 1,
            onTap: () => setState(() => _currentPage--),
          ),
          const SizedBox(width: 16),
          ...pageWidgets,
          const SizedBox(width: 16),
          // Next button
          _buildNavButton(
            label: 'NEXT',
            icon: Icons.chevron_right_rounded,
            isEnabled: _currentPage < totalPages,
            onTap: () => setState(() => _currentPage++),
            isTrailing: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
    bool isTrailing = false,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailing) Icon(icon, color: isEnabled ? Colors.white : const Color(0xFF94A3B8), size: 18),
            if (!isTrailing) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            if (isTrailing) const SizedBox(width: 6),
            if (isTrailing) Icon(icon, color: isEnabled ? Colors.white : const Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}

class _FinishedOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _FinishedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isAdvance = order['_is_advance'] == true;
    final isReservation = order['_is_reservation'] == true;

    final orderId = isReservation
        ? 'EVENT'
        : (isAdvance
            ? 'ADV-${order['id'].toString().substring(0, 4).toUpperCase()}'
            : _formatOrderId(order));

    final customer = order['customer_name']?.toString() ?? 'Guest';
    final total = isReservation
        ? null
        : (order['total_price'] ?? order['total_amount'] ?? 0.0).toDouble();

    final createdAt = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())
        : null;

    String timeStr;
    if (isReservation) {
      timeStr = order['event_date']?.toString() ?? '—';
    } else if (isAdvance) {
      timeStr = '${order['order_date']} ${order['order_time']}';
    } else {
      timeStr = createdAt != null ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal()) : '—';
    }

    final tableNumber = order['table_number']?.toString();
    final orderType = isReservation
        ? (order['event_type']?.toString())
        : order['order_type']?.toString();
    final numberOfGuests = order['number_of_guests'];

    // Left-side accent color per order type
    final Color accentColor = isReservation
        ? const Color(0xFF7C3AED)
        : (isAdvance ? const Color(0xFF0284C7) : const Color(0xFF0B211D));

    // Status info
    final rs = order['refund_status']?.toString() ?? 'none';
    final statusStr = order['status']?.toString().toLowerCase() ?? '';
    final isRefunded = rs == 'full_refund' || rs == 'partial_refund' || statusStr == 'refunded' || statusStr == 'cancelled';
    final badgeText = (rs == 'full_refund' || statusStr == 'refunded')
        ? 'REFUNDED'
        : (statusStr == 'cancelled' ? 'CANCELLED' : 'SERVED');
    final Color statusBg = isRefunded
        ? (statusStr == 'cancelled' ? const Color(0xFFDC2626) : const Color(0xFFEF4444))
        : const Color(0xFF059669);
    final IconData statusIcon = isRefunded ? Icons.cancel_outlined : Icons.check_circle_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDEB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar
              Container(width: 5, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      // Order ID badge column
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Text(
                                orderId,
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Details column
                      Expanded(
                        flex: 4,
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _detailChip(Icons.person_outline_rounded, customer.toUpperCase(), bold: true),
                            _detailChip(Icons.schedule_outlined, timeStr),
                            if (numberOfGuests != null)
                              _detailChip(Icons.people_outline_rounded, '$numberOfGuests pax'),
                            if ((isAdvance || isReservation) && orderType != null)
                              _detailChip(
                                isReservation ? Icons.celebration_outlined : (orderType == 'Pickup' ? Icons.shopping_bag_outlined : Icons.restaurant_outlined),
                                orderType.toUpperCase(),
                              ),
                            if (!isAdvance && !isReservation && tableNumber != null && tableNumber.isNotEmpty)
                              _detailChip(Icons.table_restaurant_outlined, 'Table $tableNumber'),
                          ],
                        ),
                      ),
                      // Amount column
                      Expanded(
                        flex: 2,
                        child: Text(
                          total != null ? '₱${NumberFormat('#,##0.00').format(total)}' : '—',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF0F2C27),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Status badge column
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: statusBg.withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, {bool bold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: bold ? const Color(0xFF0F2C27) : const Color(0xFF475569),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 3 — INVENTORY REQUESTS
// ══════════════════════════════════════════════════════════
class _InventoryRequestTab extends StatefulWidget {
  const _InventoryRequestTab();

  @override
  State<_InventoryRequestTab> createState() => _InventoryRequestTabState();
}

class _InventoryRequestTabState extends State<_InventoryRequestTab> {
  int _currentPage = 1;
  static const int _itemsPerPage = 20;

  // Form controllers
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  String _selectedUnit = '';
  String _selectedPriority = 'Low';
  bool _submitting = false;

  static const _priorities = ['Low', 'Urgent'];

  static const _priorityColors = {
    'Low': Color(0xFFFFA726),
    'Urgent': Color(0xFFE53935),
  };

  static const _statusColors = {
    'Pending': Color(0xFFFFA726),
    'Approved': Color(0xFF4CAF50),
    'Rejected': Color(0xFFE53935),
  };

  List<String> _availableItems = [];
  Map<String, String> _itemUnits = {}; // Map to store item -> unit mapping
  Map<String, int> _itemStocks = {}; // Map to store item -> available quantity

  List<String> _suggestions = []; // Auto-complete suggestions
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
    _itemCtrl.addListener(_onItemChanged);
  }

  void _resetUnit() {
    setState(() {
      _selectedUnit = '';
      _unitCtrl.text = '';
    });
  }

  void _onItemChanged() {
    final itemName = _itemCtrl.text.trim();

    // Auto-update unit if exact match found
    if (_itemUnits.containsKey(itemName)) {
      setState(() {
        _selectedUnit = _itemUnits[itemName]!;
        _unitCtrl.text = _selectedUnit;
      });
    } else {
      _resetUnit();
    }

    // Update suggestions for auto-complete
    if (itemName.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    } else {
      final matches = _availableItems
          .where((item) => item.toLowerCase().contains(itemName.toLowerCase()))
          .take(5) // Limit to 5 suggestions
          .toList();

      setState(() {
        _suggestions = matches;
        _showSuggestions = matches.isNotEmpty && !matches.contains(itemName);
      });
    }
  }

  void _selectSuggestion(String suggestion) {
    _itemCtrl.text = suggestion;
    setState(() {
      _selectedUnit = _itemUnits[suggestion] ?? 'pcs';
      _unitCtrl.text = _selectedUnit;
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  Future<void> _loadAvailableItems() async {
    try {
      // 1. Fetch main inventory
      final items = await Supabase.instance.client
          .from('inventory')
          .select('name, unit, quantity')
          .order('name');



      if (mounted) {
        setState(() {
          _availableItems = items.map((i) => i['name'].toString()).toList();
          _itemUnits = {
            for (var item in items)
              item['name'].toString(): item['unit']?.toString() ?? 'pcs',
          };
          _itemStocks = {
            for (var item in items)
              item['name'].toString(): (item['quantity'] as num?)?.toInt() ?? 0,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final itemName = _itemCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim());

    // Validation: Check if item exists in Pagsanjaninv inventory
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_availableItems.contains(itemName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$itemName" is not available in inventory. Please select from available items.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate quantity against available stock
    final availableStock = _itemStocks[itemName] ?? 0;
    if (qty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot request $qty $itemName. Only $availableStock ${_itemUnits[itemName] ?? 'pcs'} available in inventory.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final chef = Supabase.instance.client.auth.currentUser?.email ?? 'chef';
      await Supabase.instance.client.from('kitchen_requests').insert({
        'item_name': itemName,
        'quantity_needed': qty,
        'unit': _selectedUnit,
        'priority': _selectedPriority,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'requested_by': chef,
        'status': 'Pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Send notification to Inventory/Admin
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: chef.split('@')[0],
        actionType: 'stock_request',
        reservationId: 'N/A',
        eventType: 'Stock Request: $itemName ($qty)',
      );

      if (mounted) {
        _itemCtrl.clear();
        _qtyCtrl.clear();
        _noteCtrl.clear();
        setState(() {
          _resetUnit();
          _selectedPriority = 'Normal';
          _submitting = false;
        });

        // Show success dialog with redirect option
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Request Submitted!',
                  style: TextStyle(color: AppTheme.darkGrey),
                ),
              ],
            ),
            content: const Text(
              'Your stock request has been sent to the inventory team. You can track its status in the Pagsanjaninv dashboard.',
              style: TextStyle(color: AppTheme.darkGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppTheme.mediumGrey),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Request Form ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.add_shopping_cart,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Request Ingredients',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
                const SizedBox(height: 16),

                // Item name with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lightField(
                      _itemCtrl,
                      'Item Name',
                      Icons.inventory_2_outlined,
                    ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _suggestions.map((suggestion) {
                            final unit = _itemUnits[suggestion] ?? '';
                            final stock = _itemStocks[suggestion] ?? 0;
                            return InkWell(
                              onTap: () => _selectSuggestion(suggestion),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(
                                        0xFFE5E7EB,
                                      ).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            suggestion,
                                            style: const TextStyle(
                                              color: Color(0xFF1E293B),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Available: $stock $unit',
                                            style: TextStyle(
                                              color: stock == 0
                                                  ? AppTheme.errorRed
                                                  : stock < 10
                                                  ? AppTheme.warningOrange
                                                  : AppTheme.successGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        unit,
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Qty + Unit row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lightField(
                            _qtyCtrl,
                            'Quantity',
                            Icons.numbers,
                            isNumber: true,
                            suffixText:
                                _itemStocks.containsKey(_itemCtrl.text.trim())
                                ? 'Max: ${_itemStocks[_itemCtrl.text.trim()]}'
                                : null,
                            onChanged: (val) {
                              final currentItem = _itemCtrl.text.trim();
                              if (_itemStocks.containsKey(currentItem)) {
                                final maxStock = _itemStocks[currentItem]!;
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed > maxStock) {
                                  _qtyCtrl.text = maxStock.toString();
                                  _qtyCtrl
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(offset: _qtyCtrl.text.length),
                                  );
                                } else if (parsed != null && parsed < 1) {
                                  _qtyCtrl.text = '1';
                                  _qtyCtrl
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(offset: _qtyCtrl.text.length),
                                  );
                                }
                              }
                            },
                          ),
                          if (_itemStocks.containsKey(_itemCtrl.text.trim()))
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                'Available in Inventory: ${_itemStocks[_itemCtrl.text.trim()]} ${_itemUnits[_itemCtrl.text.trim()] ?? ''}',
                                style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _lightField(
                        _unitCtrl,
                        'Unit',
                        Icons.straighten,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Priority
                const Text(
                  'Priority',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((p) {
                    final selected = _selectedPriority == p;
                    final color = _priorityColors[p] ?? AppTheme.infoBlue;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedPriority = p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.1)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              p,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? color
                                    : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Note
                _lightField(
                  _noteCtrl,
                  'Note (optional)',
                  Icons.note_alt_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 18),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Submitting…' : 'Send Request to Inventory',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Request History ──────────────────────────
          const Text(
            'MY REQUESTS',
            style: TextStyle(
              color: Color(0xFF8892B0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('kitchen_requests')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }
              final requests = snap.data!;
              if (requests.isEmpty) {
                return _buildEmptyState(
                  Icons.inbox_outlined,
                  'No requests yet',
                  'Submit a request above.',
                );
              }
              final int totalPages = (requests.length / _itemsPerPage).ceil();
              if (_currentPage > totalPages && totalPages > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _currentPage = totalPages);
                });
              }
              final int startIndex = (_currentPage - 1) * _itemsPerPage;
              int endIndex = startIndex + _itemsPerPage;
              if (endIndex > requests.length) endIndex = requests.length;
              final currentRequests = (startIndex < requests.length)
                  ? requests.sublist(startIndex, endIndex)
                  : <Map<String, dynamic>>[];

              return Column(
                children: [
                  ...currentRequests.map(
                    (r) => _RequestHistoryCard(
                      request: r,
                      statusColors: _statusColors,
                      priorityColors: _priorityColors,
                    ),
                  ),
                  if (totalPages > 1) _buildPagination(totalPages),
                ],
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _lightField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
    String? suffixText,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: isNumber
          ? (value) {
              // Filter out non-numeric characters
              final filteredValue = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (filteredValue != value) {
                ctrl.value = TextEditingValue(
                  text: filteredValue,
                  selection: TextSelection.collapsed(
                    offset: filteredValue.length,
                  ),
                );
              }
              if (onChanged != null) onChanged(filteredValue);
            }
          : onChanged,
      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 18),
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
  
  Widget _buildPagination(int totalPages) {
    List<Widget> pageWidgets = [];
    bool lastWasEllipsis = false;
    // Show more numbers: current +/- 2
    for (int i = 1; i <= totalPages; i++) {
      if (totalPages <= 7 || i == 1 || i == totalPages || (i >= _currentPage - 2 && i <= _currentPage + 2)) {
        final isSelected = i == _currentPage;
        pageWidgets.add(
          GestureDetector(
            onTap: () => setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$i',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
        lastWasEllipsis = false;
      } else {
        if (!lastWasEllipsis) {
          pageWidgets.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 16)),
          ));
          lastWasEllipsis = true;
        }
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prev button
          _buildNavButton(
            label: 'PREV',
            icon: Icons.chevron_left_rounded,
            isEnabled: _currentPage > 1,
            onTap: () => setState(() => _currentPage--),
          ),
          const SizedBox(width: 16),
          ...pageWidgets,
          const SizedBox(width: 16),
          // Next button
          _buildNavButton(
            label: 'NEXT',
            icon: Icons.chevron_right_rounded,
            isEnabled: _currentPage < totalPages,
            onTap: () => setState(() => _currentPage++),
            isTrailing: true,
          ),
        ],
      ),
    );
  }
  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
    bool isTrailing = false,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailing) Icon(icon, color: isEnabled ? Colors.white : const Color(0xFF94A3B8), size: 18),
            if (!isTrailing) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            if (isTrailing) const SizedBox(width: 6),
            if (isTrailing) Icon(icon, color: isEnabled ? Colors.white : const Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Map<String, Color> statusColors;
  final Map<String, Color> priorityColors;

  const _RequestHistoryCard({
    required this.request,
    required this.statusColors,
    required this.priorityColors,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'Pending';
    final priority = request['priority']?.toString() ?? 'Normal';
    final statusColor = statusColors[status] ?? AppTheme.warningOrange;
    final priorityColor = priorityColors[priority] ?? AppTheme.infoBlue;
    final createdAt = request['created_at'] != null
        ? DateTime.tryParse(request['created_at'].toString())
        : null;
    final timeStr = createdAt != null
        ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal())
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      request['item_name']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${request['quantity_needed']} ${request['unit']}  •  $timeStr',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                if ((request['note']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      request['note'].toString(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 4 — STOCK VIEW (Read-Only)
// ══════════════════════════════════════════════════════════
class _StockViewTab extends StatefulWidget {
  const _StockViewTab();

  @override
  State<_StockViewTab> createState() => _StockViewTabState();
}

class _StockViewTabState extends State<_StockViewTab> {
  String _search = '';
  String? _selectedFilter;

  // ── Bulk Request State (Imported for seamless layout) ──
  bool _submitting = false;
  List<String> _availableItems = [];
  final Map<String, String> _itemUnits = {}; 
  final Map<String, int> _itemStocks = {};
  final Map<String, int> _kitchenStocks = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
  }

  // ── Duplicate Request Logic for Local Access ──
  Future<void> _loadAvailableItems() async {
    try {
      final items = await Supabase.instance.client
          .from('inventory')
          .select('name, unit, quantity')
          .order('name');
      final kitchenItems = await Supabase.instance.client
          .from('kitchen_inventory')
          .select('name, quantity');

      if (mounted) {
        setState(() {
          // Combine items from both main inventory and kitchen inventory
          final allItemNames = <String>{};
          
          // Add items from main inventory
          for (var item in items) {
            final name = item['name'].toString();
            allItemNames.add(name);
            _itemUnits[name] = item['unit']?.toString() ?? 'pcs';
            _itemStocks[name] = (item['quantity'] as num?)?.toInt() ?? 0;
          }
          
          // Add items from kitchen inventory (including ones not in main inventory)
          for (var item in kitchenItems) {
            final name = item['name'].toString();
            allItemNames.add(name);
            _kitchenStocks[name] = (item['quantity'] as num?)?.toInt() ?? 0;
          }
          
          _availableItems = allItemNames.toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _requestAllItems() => _runBulkRequest(
        title: 'All available items',
        filter: (name, mainQty, kitchenQty) => _kitchenStocks.containsKey(name) && mainQty > 0,
        note: 'Bulk request (Restock all)',
      );

  Future<void> _requestAllOutOfStock() => _runBulkRequest(
        title: 'Only out-of-stock items',
        filter: (name, mainQty, kitchenQty) => _kitchenStocks.containsKey(name) && kitchenQty <= 0 && mainQty > 0,
        note: 'Bulk request (Kitchen is OUT)',
      );

  Future<void> _requestAllLowStock() => _runBulkRequest(
        title: 'Only low-stock items',
        filter: (name, mainQty, kitchenQty) =>
            _kitchenStocks.containsKey(name) && kitchenQty >= 1 && kitchenQty <= 10 && mainQty > 0,
        note: 'Bulk request (Kitchen is LOW)',
      );

  Future<void> _runBulkRequest({
    required String title,
    required bool Function(String name, int mainQty, int kitchenQty) filter,
    required String note,
  }) async {
    setState(() => _submitting = true);
    try {
      await _loadAvailableItems();
      if (_availableItems.isEmpty) {
        setState(() => _submitting = false);
        return;
      }
      final pendingRequests = await Supabase.instance.client
          .from('kitchen_requests')
          .select('item_name')
          .eq('status', 'Pending');
      final pendingNames =
          (pendingRequests as List).map((r) => r['item_name'].toString()).toSet();

      final itemsToRequest = _availableItems.where((name) {
        final mainStock = _itemStocks[name] ?? 0;
        final kitchenStock = _kitchenStocks[name] ?? 0;
        return filter(name, mainStock, kitchenStock) &&
            !pendingNames.contains(name);
      }).toList();

      if (itemsToRequest.isEmpty) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No items for "$title" need to be requested.'),
              backgroundColor: AppTheme.infoBlue,
            ),
          );
        }
        return;
      }

      final chef = Supabase.instance.client.auth.currentUser?.email ?? 'chef';
      final requests = itemsToRequest.map((name) {
        final stock = _itemStocks[name] ?? 0;
        final kitchenStock = _kitchenStocks[name] ?? 0;
        
        // Calculate 40% of total stock (rounded to nearest integer, minimum 1)
        final requestedQuantity = (stock * 0.4).round();
        final quantityNeeded = requestedQuantity > 0 ? requestedQuantity : 1;
        
        // Set priority based on kitchen stock status
        String priority;
        if (kitchenStock <= 0) {
          priority = 'Urgent';  // Out of Stock -> Urgent
        } else if (kitchenStock <= 10) {
          priority = 'High';    // Low Stock -> High
        } else {
          priority = 'Normal';
        }

        return {
          'item_name': name,
          'quantity_needed': quantityNeeded,
          'unit': _itemUnits[name] ?? 'pcs',
          'priority': priority,
          'note': note,
          'requested_by': chef,
          'status': 'Pending',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      await Supabase.instance.client.from('kitchen_requests').insert(requests);

      // Create a descriptive event type for the notification
      String eventTypeStr;
      if (requests.length == 1) {
        eventTypeStr = 'Stock Request: ${requests[0]['item_name']} (${requests[0]['quantity_needed']})';
      } else {
        final names = requests.map((r) => r['item_name']).take(3).join(', ');
        final suffix = requests.length > 3 ? '... +${requests.length - 3} more' : '';
        eventTypeStr = 'Bulk Request (${requests.length} items): $names$suffix';
      }

      // Send notification to Inventory/Admin
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: chef.split('@')[0],
        actionType: 'stock_request',
        reservationId: 'N/A',
        eventType: eventTypeStr,
      );

      if (mounted) {
        setState(() => _submitting = false);
        
        final skippedCount = _availableItems.where((name) {
          final mainStock = _itemStocks[name] ?? 0;
          final kitchenStock = _kitchenStocks[name] ?? 0;
          return filter(name, mainStock, kitchenStock) && pendingNames.contains(name);
        }).length;

        String msg = 'Successfully requested ${requests.length} items!';
        if (skippedCount > 0) {
          msg += ' ($skippedCount items skipped as they are already pending)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'OUT OF STOCK';
    if (quantity <= 10) return 'LOW STOCK'; 
    if (quantity < 50) return 'NORMAL';
    return 'HIGH STOCK';
  }

  Color _getStatusColor(int quantity) {
    if (quantity == 0) return AppTheme.errorRed;
    if (quantity <= 10) return AppTheme.warningOrange; 
    if (quantity < 50) return AppTheme.infoBlue;
    return AppTheme.successGreen;
  }

  IconData _getStockStatusIcon(int quantity) {
    if (quantity == 0) return Icons.remove_circle;
    if (quantity <= 10) return Icons.warning_amber_rounded; 
    if (quantity < 50) return Icons.inventory_2_rounded;
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LEFT SIDE: GRID (75%) ──
        Expanded(
          flex: 3, // 75%
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search ingredients…',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Grid
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client
                      .from('kitchen_inventory')
                      .stream(primaryKey: ['id'])
                      .order('quantity', ascending: true),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      );
                    }
                    var items = snap.data!;
                    final hasItems = items.isNotEmpty;
                    final filteredItems = items.where((i) {
                      // Apply search filter
                      final name = (i['name'] ?? '').toString().toLowerCase();
                      final matchesSearch = _search.isEmpty || name.contains(_search);

                      // Apply status filter
                      final qty = (i['quantity'] as num?)?.toInt() ?? 0;
                      final status = _getStockStatus(qty);
                      final matchesStatus =
                          _selectedFilter == null || status == _selectedFilter;

                      return matchesSearch && matchesStatus;
                    }).toList();

                    if (!hasItems) {
                      return _buildEmptyState(
                        Icons.inventory_2_outlined,
                        'No items in kitchen stock',
                        'Request items from inventory first',
                      );
                    }

                    if (filteredItems.isEmpty) {
                      String message = 'No items found';
                      String subtitle = 'Try adjusting your search';
                      if (_selectedFilter != null && _search.isEmpty) {
                        subtitle = 'No items with $_selectedFilter status';
                      } else if (_selectedFilter != null && _search.isNotEmpty) {
                        subtitle = 'No $_selectedFilter items matching "$_search"';
                      } else if (_selectedFilter == null && _search.isNotEmpty) {
                        subtitle = 'No items matching "$_search"';
                      }
                      return _buildEmptyState(
                        Icons.inventory_2_outlined,
                        message,
                        subtitle,
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (_, i) {
                        final item = filteredItems[i];
                        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                        final color = _getStatusColor(qty);
                        final label = _getStockStatus(qty);
                        final icon = _getStockStatusIcon(qty);
                        return FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 180,
                            height: 180 / 1.05,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, color: color, size: 22),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['name']?.toString() ?? '—',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['category']?.toString() ?? '—',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$qty ${item['unit'] ?? ''}',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── RIGHT SIDE: SIDEBAR (25%) ──
        Expanded(
          flex: 1, // 25%
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('kitchen_inventory')
                  .stream(primaryKey: ['id']),
              builder: (context, snap) {
                final items = snap.data ?? [];
                int out = 0, low = 0, ok = 0, high = 0;
                for (final i in items) {
                  final qty = (i['quantity'] as num?)?.toInt() ?? 0;
                  if (qty == 0) {
                    out++;
                  } else if (qty <= 10) {
                    low++;
                  } else if (qty < 50) {
                    ok++;
                  } else {
                    high++;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // QUICK REQUESTS (TOP 50%)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'QUICK REQUESTS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _bulkBtn(
                              onPressed: _requestAllItems,
                              label: 'Request All Stock',
                              icon: Icons.auto_awesome,
                            ),
                            const SizedBox(height: 10),
                            _bulkBtn(
                              onPressed: _requestAllOutOfStock,
                              label: 'Out of Stock',
                              icon: Icons.remove_circle_outline,
                              color: AppTheme.errorRed,
                            ),
                            const SizedBox(height: 10),
                            _bulkBtn(
                              onPressed: _requestAllLowStock,
                              label: 'Low Stock',
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.warningOrange,
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(color: Color(0xFFE5E7EB)),
                      ),

                      // STOCK SUMMARY (BOTTOM 50%)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'STOCK SUMMARY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  _summaryChip(
                                    'OUT OF STOCK',
                                    out.toString(),
                                    AppTheme.errorRed,
                                    isSelected: _selectedFilter == 'OUT OF STOCK',
                                    onTap: () => setState(() {
                                      _selectedFilter = _selectedFilter == 'OUT OF STOCK' 
                                          ? null 
                                          : 'OUT OF STOCK';
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  _summaryChip(
                                    'LOW STOCK',
                                    low.toString(),
                                    AppTheme.warningOrange,
                                    isSelected: _selectedFilter == 'LOW STOCK',
                                    onTap: () => setState(() {
                                      _selectedFilter = _selectedFilter == 'LOW STOCK' 
                                          ? null 
                                          : 'LOW STOCK';
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  _summaryChip(
                                    'NORMAL',
                                    ok.toString(),
                                    AppTheme.infoBlue,
                                    isSelected: _selectedFilter == 'NORMAL',
                                    onTap: () => setState(() {
                                      _selectedFilter = _selectedFilter == 'NORMAL' 
                                          ? null 
                                          : 'NORMAL';
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  _summaryChip(
                                    'HIGH STOCK',
                                    high.toString(),
                                    AppTheme.successGreen,
                                    isSelected: _selectedFilter == 'HIGH STOCK',
                                    onTap: () => setState(() {
                                      _selectedFilter = _selectedFilter == 'HIGH STOCK' 
                                          ? null 
                                          : 'HIGH STOCK';
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _bulkBtn({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    Color color = AppTheme.primaryColor,
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: _submitting ? null : onPressed,
        icon: Icon(icon, size: 18, color: _submitting ? Colors.grey : color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _submitting ? Colors.grey : color,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
        ),
      ),
    );
  }

  Widget _summaryChip(
    String label,
    String count,
    Color color, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════════════════

/// Returns the order ID exactly as shown on the printed receipt — always matches.
String _formatOrderId(Map<String, dynamic> order) {
  final txn = order['transaction_id']?.toString();
  if (txn != null && txn.isNotEmpty) return '#$txn';
  // Fallback for very old orders without a transaction_id
  final id = order['id']?.toString() ?? '???';
  final asInt = int.tryParse(id);
  return '#${asInt != null ? asInt.toString().padLeft(3, '0') : id.substring(id.length > 6 ? id.length - 6 : 0).toUpperCase()}';
}

/// Calculates the kitchen "prepare by" time — 20 minutes before the customer's scheduled order time.
/// e.g. order_time = "10:00 AM" → returns "9:40 AM"
String _calcPrepareTime(String? orderTime) {
  if (orderTime == null || orderTime.isEmpty) return '—';
  try {
    // Try parsing common formats: "10:00 AM", "10:00", "10:00:00"
    DateTime? parsed;
    final formats = ['h:mm a', 'h:mm:ss a', 'HH:mm', 'HH:mm:ss', 'h:mm'];
    for (final fmt in formats) {
      try {
        parsed = DateFormat(fmt).parse(orderTime);
        break;
      } catch (_) {}
    }
    if (parsed == null) return orderTime;
    final prepareTime = parsed.subtract(const Duration(minutes: 20));
    return DateFormat('h:mm a').format(prepareTime);
  } catch (_) {
    return orderTime;
  }
}

/// Parses the order scheduled date and time and subtracts 20 minutes to get the prepare-by DateTime.
DateTime? _getPrepareByDateTime(String? dateStr, String? timeStr) {
  if (dateStr == null || dateStr.isEmpty || timeStr == null || timeStr.isEmpty) return null;
  try {
    final parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate == null) return null;
    
    DateTime? parsedTime;
    final formats = ['h:mm a', 'h:mm:ss a', 'HH:mm', 'HH:mm:ss', 'h:mm'];
    for (final fmt in formats) {
      try {
        parsedTime = DateFormat(fmt).parse(timeStr);
        break;
      } catch (_) {}
    }
    if (parsedTime == null) return null;
    
    final scheduledDateTime = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
      parsedTime.second,
    );
    return scheduledDateTime.subtract(const Duration(minutes: 20));
  } catch (_) {
    return null;
  }
}

Widget _buildEmptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF133831).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xFF133831).withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 48, color: const Color(0xFF133831)),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    ),
  );
}
