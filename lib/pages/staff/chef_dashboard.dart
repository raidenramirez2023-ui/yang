import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/url_sync_helper.dart';
import 'package:yang_chow/services/notification_service.dart';

// ══════════════════════════════════════════════════════════
//  CHEF DASHBOARD PAGE
// ══════════════════════════════════════════════════════════
class ChefDashboardPage extends StatefulWidget {
  final int initialTab;

  const ChefDashboardPage({super.key, this.initialTab = 0});

  @override
  State<ChefDashboardPage> createState() => _ChefDashboardPageState();
}

class _ChefDashboardPageState extends State<ChefDashboardPage>
    with TickerProviderStateMixin {
  late int _currentTab;
  late final PageController _pageController;
  void Function()? _cancelPopState;

  static const List<String> _tabUrls = [
    '/chef/dashboard',
    '/chef/events',
    '/chef/finished',
    '/chef/requests',
    '/chef/stock',
  ];

  void _syncUrl() {
    if (_currentTab >= 0 && _currentTab < _tabUrls.length) {
      UrlSyncHelper.updateUrl(_tabUrls[_currentTab]);
    }
  }

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

  // ── Top Toast Notification Overlay for Chef ──
  OverlayEntry? _currentChefTopToastEntry;
  Timer? _chefTopToastTimer;
  Timer? _eventReminderTimer;
  final Set<String> _shownToastChefNotificationIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _chefNotifsSubscription;

  void _dismissChefTopToast() {
    _chefTopToastTimer?.cancel();
    _chefTopToastTimer = null;
    _currentChefTopToastEntry?.remove();
    _currentChefTopToastEntry = null;
  }

  void _showChefTopToast({
    required Widget content,
    Duration? duration,
  }) {
    if (!mounted) return;
    _dismissChefTopToast();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ChefTopToastWidget(
        onDismiss: () {
          if (_currentChefTopToastEntry == entry) {
            _dismissChefTopToast();
          }
        },
        duration: duration,
        child: content,
      ),
    );

    _currentChefTopToastEntry = entry;
    overlay.insert(entry);

    if (duration != null) {
      _chefTopToastTimer = Timer(duration, () {
        if (_currentChefTopToastEntry == entry) {
          _dismissChefTopToast();
        }
      });
    }
  }

  bool _hasCheckedLoginEventsModal = false;

  Future<void> _checkUpcomingEventsOnLogin() async {
    if (_hasCheckedLoginEventsModal || !mounted) return;
    _hasCheckedLoginEventsModal = true;

    try {
      final rows = await Supabase.instance.client
          .from('reservations')
          .select()
          .eq('is_menu_based', true)
          .neq('kitchen_status', 'Done')
          .order('event_date', ascending: true);

      if (!mounted) return;

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      final upcomingEvents = rows.where((r) {
        final isMenuBased = r['is_menu_based'] == true;
        final ps = r['payment_status']?.toString().toLowerCase();
        final isPaid = ps == 'paid' || ps == 'deposit_paid' || ps == 'fully_paid';
        final menuItems = r['selected_menu_items'];
        final hasMenu = menuItems != null && (menuItems as Map).isNotEmpty;
        final isNotServed = r['kitchen_status']?.toString() != 'Done';
        final status = r['status']?.toString().toLowerCase();
        final isApproved = status == 'confirmed' || status == 'completed';
        final eventDateStr = r['event_date']?.toString();

        if (!isMenuBased || !isPaid || !hasMenu || !isNotServed || !isApproved || eventDateStr == null) {
          return false;
        }

        try {
          final eventDate = DateTime.parse(eventDateStr);
          final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
          final daysUntil = eventDateOnly.difference(todayDate).inDays;
          // Only include events that are 2 to 5 days ahead from today
          return daysUntil >= 2 && daysUntil <= 5;
        } catch (_) {
          return false;
        }
      }).toList();

      if (upcomingEvents.isNotEmpty && mounted) {
        _showUpcomingEventsNoticeModal(upcomingEvents);
      }
    } catch (e) {
      debugPrint('Error checking login upcoming events: $e');
    }
  }

  void _showUpcomingEventsNoticeModal(List<Map<String, dynamic>> events) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _UpcomingEventsNoticeDialog(
        events: events,
        onViewEventsTab: () {
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          setState(() => _currentTab = 1);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _pageController = PageController(initialPage: widget.initialTab);
    _syncUrl();
    _cancelPopState = UrlSyncHelper.listenPopState((path) {
      final idx = _tabUrls.indexOf(path);
      if (idx != -1 && idx != _currentTab && mounted) {
        setState(() => _currentTab = idx);
        _pageController.jumpToPage(idx);
      }
    });

    _listenForNewOrders();

    // Check for 2-5 days upcoming event reminders & day-of-event notifications immediately and every 5 minutes
    NotificationService.checkAndSendUpcomingEventReminders();
    _eventReminderTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      NotificationService.checkAndSendUpcomingEventReminders();
    });

    // Check on login if there are upcoming events in 2 to 5 days and show modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpcomingEventsOnLogin();
    });

    _chefNotifsSubscription = NotificationService.getKitchenNotificationsStream().listen((notifs) {
      if (!mounted) return;
      final unread = notifs.where((n) => n['is_read'] == false).toList();
      if (unread.isNotEmpty) {
        final latest = unread.first;
        final id = latest['id']?.toString();
        if (id != null && !_shownToastChefNotificationIds.contains(id)) {
          _shownToastChefNotificationIds.add(id);
          _showChefNotificationToast(latest);
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelPopState?.call();
    _pageController.dispose();
    _orderStream?.cancel();
    _popupDebounceTimer?.cancel();
    _eventReminderTimer?.cancel();
    _chefNotifsSubscription?.cancel();
    _dismissChefTopToast();
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
                onPageChanged: (idx) {
                  setState(() => _currentTab = idx);
                  _syncUrl();
                },
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
    // Disable stock alert popups for chef
    if (n['action_type'] == 'stock_alert') {
      return const SizedBox.shrink();
    }

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
    
    // Disable stock alert popups for chef
    if (actionType == 'stock_alert') {
      _closePopup();
      return;
    }

    // If chef is already on the Kitchen tab (Tab 0), avoid stealing focus with a blocking modal
    // for standard kitchen orders, as the live ticket list already updates in real-time.
    if (_currentTab == 0 && (actionType == 'pos_order' || (actionType == 'advance_order_ticket' && !notification['event_type'].toString().contains('Event Reservation')))) {
      _closePopup();
      return;
    }

    // Set flag to prevent multiple popups
    setState(() {
      _isPopupShowing = true;
    });
    
    // Mark all unread notifications of the same type as dismissed
    _dismissAllSimilarNotifications(actionType);
    
    // Route to appropriate popup based on action type
    switch (actionType) {
      case 'stock_alert':
        _closePopup();
        break;
      case 'pos_order':
        _showNewOrderPopup(notification);
        break;
      case 'event_reminder':
      case 'event_today':
        _showEventReservationPopup(notification);
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
    if (mounted) {
      setState(() {
        _isPopupShowing = false;
      });
    }
  }

  void _dismissAllSimilarNotifications(String actionType) {
    setState(() {
      _dismissedNotificationIds.add('all_$actionType');
    });
  }

  /// Enterprise alert dialog wrapper for all notification popups
  void _showEnterpriseNoticeDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String hintText,
    required String actionLabel,
    required VoidCallback onAction,
    required VoidCallback onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogWidth = screenWidth > 520 ? 460.0 : screenWidth * 0.92;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Executive Dark Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0B211D), Color(0xFF133831)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: iconColor.withValues(alpha: 0.5)),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Dismiss',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF334155),
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hintText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B211D).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0B211D).withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF0B211D), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  hintText,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF0B211D),
                                    fontSize: 12.5,
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
                // Footer Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Dismiss',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B211D),
                            foregroundColor: const Color(0xFFE6C374),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0x66E6C374)),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNewOrderPopup(Map<String, dynamic> notification) {
    final eventType = notification['event_type']?.toString() ?? 'New POS Order';
    
    String title = 'New Kitchen Order';
    String message = 'POS service staff placed a new order. Ticket is ready on the Kitchen Display.';
    
    if (eventType.contains('new POS orders')) {
      final regex = RegExp(r'(\d+)\s+new\s+POS\s+orders');
      final match = regex.firstMatch(eventType);
      if (match != null) {
        final count = match.group(1) ?? '1';
        title = 'New Kitchen Orders';
        message = '$count new orders have been submitted. Please prepare and dispatch.';
      }
    }
    
    _showEnterpriseNoticeDialog(
      icon: Icons.restaurant_menu_rounded,
      iconColor: const Color(0xFF10B981),
      title: title,
      message: message,
      hintText: 'Switch to the Kitchen Display to start preparation',
      actionLabel: 'View in Kitchen',
      onDismiss: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
      onAction: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _currentTab = 0);
      },
    );
  }

  void _showAdvanceOrderPopup(Map<String, dynamic> notification) {
    _showEnterpriseNoticeDialog(
      icon: Icons.schedule_rounded,
      iconColor: const Color(0xFF0284C7),
      title: 'Advance Order Ready to Cook',
      message: 'A scheduled advance order is now ready for the kitchen to prepare.',
      hintText: 'Check scheduled time and special instructions',
      actionLabel: 'View Orders',
      onDismiss: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
      onAction: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _currentTab = 0);
      },
    );
  }

  void _showStockApprovedPopup(Map<String, dynamic> notification) {
    final eventType = notification['event_type']?.toString() ?? 'Stock Approved';
    
    String message = 'Your kitchen requisition request has been approved by Inventory management.';
    if (eventType.contains('Stock Approved:')) {
      final regex = RegExp(r'Stock Approved:\s*(\d+)\s+items?');
      final match = regex.firstMatch(eventType);
      if (match != null) {
        final count = match.group(1) ?? '1';
        message = '$count requisition item${count == '1' ? '' : 's'} approved and updated in kitchen inventory.';
      } else {
        message = 'Requested stock approved and added to your inventory.';
      }
    }
    
    _showEnterpriseNoticeDialog(
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Stock Request Approved',
      message: message,
      hintText: 'Review updated quantities in the Stock Management view',
      actionLabel: 'View Stock',
      onDismiss: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
      onAction: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
        _pageController.animateToPage(
          4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _currentTab = 4);
      },
    );
  }

  void _showEventReservationPopup(Map<String, dynamic> notification) {
    final title = _getNotificationTitle(notification);
    final subtitle = _getNotificationSubtitle(notification);
    final isToday = notification['action_type'] == 'event_today';
    final iconColor = isToday ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final iconData = isToday ? Icons.notification_important_rounded : Icons.event_note_rounded;

    _showEnterpriseNoticeDialog(
      icon: iconData,
      iconColor: iconColor,
      title: title,
      message: subtitle,
      hintText: isToday
          ? "Today's scheduled event requires immediate meal and ingredient preparation"
          : 'Check the Events tab for catering requirements and guest menu',
      actionLabel: isToday ? "View Today's Events" : 'View Events Tab',
      onDismiss: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
      onAction: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _currentTab = 1);
      },
    );
  }

  void _showGenericNotificationPopup(Map<String, dynamic> notification) {
    final title = _getNotificationTitle(notification);
    final subtitle = _getNotificationSubtitle(notification);
    
    _showEnterpriseNoticeDialog(
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFFE6C374),
      title: title,
      message: subtitle,
      hintText: '',
      actionLabel: 'Acknowledge',
      onDismiss: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
      onAction: () {
        setState(() {
          _dismissedNotificationIds.add(notification['id'].toString());
        });
        Navigator.pop(context);
        _closePopup();
      },
    );
  }

  // ── Header Notification Bell & Popover Center ────────────
  Widget _buildNotificationIcon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getKitchenNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadNotifications = notifications.where((n) => !n['is_read'] && n['action_type'] != 'stock_alert').toList();
        final unreadCount = unreadNotifications.length;
        final hasUnread = unreadCount > 0;

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
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (latestUnread != null) {
                    setState(() {
                      _dismissedNotificationIds.add(latestUnread!['id'].toString());
                    });
                  }
                  _showNotificationsDialog(notifications);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasUnread
                          ? const Color(0xFFE6C374).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                      width: hasUnread ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasUnread ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                        color: const Color(0xFFE6C374),
                        size: 18,
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '$unreadCount',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
    if (notifications.isNotEmpty) {
      final unreadIds = notifications
          .where((n) => n['is_read'] == false)
          .map((n) => n['id'].toString())
          .toList();
      if (unreadIds.isNotEmpty) {
        NotificationService.markVisibleAsRead(unreadIds);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ChefNotificationCenterDialog(
        notifications: notifications,
        onNavigateTab: (tabIdx) {
          _pageController.animateToPage(
            tabIdx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
          setState(() => _currentTab = tabIdx);
        },
      ),
    );
  }

  void _showChefNotificationToast(Map<String, dynamic> n) {
    if (!mounted) return;
    final title = _getNotificationTitle(n);
    final subtitle = _getNotificationSubtitle(n);
    final isToday = n['action_type'] == 'event_today';
    final isNewOrder = n['action_type'] == 'pos_order' || n['action_type'] == 'advance_order_ticket';
    final accentColor = isToday
        ? const Color(0xFFEF4444)
        : isNewOrder
            ? const Color(0xFF10B981)
            : const Color(0xFFE6C374);

    void openBellDialog() {
      _dismissChefTopToast();
      NotificationService.getKitchenNotificationsStream()
          .first
          .then((notifs) {
        if (mounted) _showNotificationsDialog(notifs);
      });
    }

    _showChefTopToast(
      duration: const Duration(seconds: 5),
      content: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openBellDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B211D).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForAction(n['action_type']),
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    backgroundColor: accentColor,
                    foregroundColor: isToday ? Colors.white : const Color(0xFF0B211D),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isToday ? Colors.white : const Color(0xFF0B211D),
                  ),
                  label: Text(
                    'VIEW',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: openBellDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action) {
      case 'stock_approved':
        return Icons.check_circle_rounded;
      case 'stock_rejected':
        return Icons.cancel_rounded;
      case 'stock_request':
        return Icons.inventory_2_rounded;
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'pos_order':
        return Icons.restaurant_rounded;
      case 'advance_order_ticket':
        return Icons.assignment_rounded;
      case 'event_today':
        return Icons.notification_important_rounded;
      case 'event_reminder':
        return Icons.event_note_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _getNotificationTitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_approved') {
      return 'Stock Request Approved';
    }
    if (n['action_type'] == 'stock_rejected') {
      return 'Stock Request Declined';
    }
    if (n['action_type'] == 'stock_request') {
      return 'Stock Request';
    }
    if (n['action_type'] == 'stock_alert') {
      return 'Kitchen Stock Alert';
    }
    if (n['action_type'] == 'pos_order') {
      return 'New Kitchen Order';
    }
    if (n['action_type'] == 'advance_order_ticket') {
      final eventType = n['event_type']?.toString() ?? '';
      if (eventType.contains('Event Reservation')) {
        return 'Event Reservation Ticket';
      }
      return 'Advance Order Ticket';
    }
    if (n['action_type'] == 'event_today') {
      return "Today's Event Alert!";
    }
    if (n['action_type'] == 'event_reminder') {
      return 'Upcoming Event Reminder';
    }
    return 'Kitchen Alert';
  }

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_approved') {
      return n['event_type'] ?? 'Inventory approved your requested kitchen stock.';
    }
    if (n['action_type'] == 'stock_rejected') {
      return n['event_type'] ?? 'Inventory declined your requested kitchen stock.';
    }
    if (n['action_type'] == 'stock_request') {
      return 'Stock requested: ${n['event_type'] ?? ''}';
    }
    if (n['action_type'] == 'stock_alert') {
      return n['event_type'] ?? 'Kitchen item low/out of stock.';
    }
    if (n['action_type'] == 'pos_order') {
      return 'New order from POS cashier. Please start preparing.';
    }
    if (n['action_type'] == 'advance_order_ticket') {
      return n['event_type'] ?? 'Advance order ticket ready for preparation.';
    }
    if (n['action_type'] == 'event_today') {
      return n['event_type'] ?? 'An event reservation is scheduled for TODAY! Please make sure meals and inventory are ready.';
    }
    if (n['action_type'] == 'event_reminder') {
      return n['event_type'] ?? 'An upcoming event reservation is scheduled within the next 2-5 days.';
    }
    return n['event_type'] ?? 'New activity in the kitchen.';
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B211D), Color(0xFF133831)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFE6C374), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Confirm Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to log out of the Chef Kitchen Display?',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF475569),
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          _dismissChefTopToast();
                          _shownToastChefNotificationIds.clear();
                          Navigator.pop(ctx);
                          await Supabase.instance.client.auth.signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/staff-login');
                          }
                        },
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
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
}

// ══════════════════════════════════════════════════════════
//  ENTERPRISE NOTIFICATION CENTER MODAL
// ══════════════════════════════════════════════════════════
class _ChefNotificationCenterDialog extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(int tabIndex) onNavigateTab;

  const _ChefNotificationCenterDialog({
    required this.notifications,
    required this.onNavigateTab,
  });

  @override
  State<_ChefNotificationCenterDialog> createState() => _ChefNotificationCenterDialogState();
}

class _ChefNotificationCenterDialogState extends State<_ChefNotificationCenterDialog> {
  int _selectedFilter = 0; // 0: All, 1: Orders, 2: Events, 3: Inventory

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  IconData _getIconForType(String action) {
    switch (action) {
      case 'stock_approved':
        return Icons.check_circle_rounded;
      case 'stock_rejected':
        return Icons.cancel_rounded;
      case 'stock_request':
        return Icons.inventory_2_rounded;
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'pos_order':
        return Icons.restaurant_rounded;
      case 'advance_order_ticket':
        return Icons.schedule_rounded;
      case 'event_today':
        return Icons.notification_important_rounded;
      case 'event_reminder':
        return Icons.event_note_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String action) {
    switch (action) {
      case 'stock_approved':
        return const Color(0xFF10B981);
      case 'stock_rejected':
        return const Color(0xFFEF4444);
      case 'stock_request':
      case 'stock_alert':
        return const Color(0xFFF59E0B);
      case 'pos_order':
        return const Color(0xFF10B981);
      case 'advance_order_ticket':
        return const Color(0xFF0284C7);
      case 'event_today':
        return const Color(0xFFEF4444);
      case 'event_reminder':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFE6C374);
    }
  }

  int _getDestinationTab(String action, String eventType) {
    if (action == 'event_today' || action == 'event_reminder' || eventType.contains('Event Reservation')) {
      return 1; // Events
    }
    if (action == 'pos_order' || action == 'advance_order_ticket') {
      return 0; // Kitchen orders
    }
    if (action == 'stock_approved' || action == 'stock_alert') {
      return 4; // Stock View
    }
    if (action == 'stock_request' || action == 'stock_rejected') {
      return 3; // Requests
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 540.0 : screenWidth * 0.94;

    final allNotifs = widget.notifications;
    final orderNotifs = allNotifs.where((n) {
      final act = n['action_type']?.toString() ?? '';
      return act == 'pos_order' || (act == 'advance_order_ticket' && !n['event_type'].toString().contains('Event Reservation'));
    }).toList();

    final eventNotifs = allNotifs.where((n) {
      final act = n['action_type']?.toString() ?? '';
      return act == 'event_today' || act == 'event_reminder' || n['event_type'].toString().contains('Event Reservation');
    }).toList();

    final stockNotifs = allNotifs.where((n) {
      final act = n['action_type']?.toString() ?? '';
      return act == 'stock_approved' || act == 'stock_rejected' || act == 'stock_request' || act == 'stock_alert';
    }).toList();

    List<Map<String, dynamic>> displayedNotifs;
    switch (_selectedFilter) {
      case 1:
        displayedNotifs = orderNotifs;
        break;
      case 2:
        displayedNotifs = eventNotifs;
        break;
      case 3:
        displayedNotifs = stockNotifs;
        break;
      default:
        displayedNotifs = allNotifs;
    }

    final filters = [
      ('All', allNotifs.length),
      ('Orders', orderNotifs.length),
      ('Events', eventNotifs.length),
      ('Stock', stockNotifs.length),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B211D), Color(0xFF133831)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C374).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFE6C374), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KITCHEN NOTIFICATION CENTER',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Activity log for orders, events, and stock requisitions',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFCBD5E1),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Category Filter Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(filters.length, (idx) {
                    final isSelected = _selectedFilter == idx;
                    final (name, count) = filters[idx];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = idx),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0B211D) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFE6C374) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected ? const Color(0xFFE6C374) : const Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE6C374).withValues(alpha: 0.25)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Notification List
            Expanded(
              child: displayedNotifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none_rounded, size: 36, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications found',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF1E293B),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'New activity will appear here in real-time.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayedNotifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = displayedNotifs[index];
                        final actionType = n['action_type']?.toString() ?? '';
                        final eventType = n['event_type']?.toString() ?? '';
                        final isRead = n['is_read'] == true;
                        final iconColor = _getColorForType(actionType);
                        final iconData = _getIconForType(actionType);

                        DateTime createdAt = DateTime.now();
                        try {
                          if (n['created_at'] != null) {
                            createdAt = DateTime.parse(n['created_at'].toString()).toLocal();
                          }
                        } catch (_) {}

                        final title = _getNotificationTitle(n);
                        final subtitle = _getNotificationSubtitle(n);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              final targetTab = _getDestinationTab(actionType, eventType);
                              widget.onNavigateTab(targetTab);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : iconColor.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead ? const Color(0xFFE2E8F0) : iconColor.withValues(alpha: 0.3),
                                  width: isRead ? 1 : 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTimeAgo(createdAt),
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFF94A3B8),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF475569),
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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

  static String _getNotificationTitle(Map<String, dynamic> n) {
    final act = n['action_type']?.toString() ?? '';
    if (act == 'stock_approved') return 'Stock Request Approved';
    if (act == 'stock_rejected') return 'Stock Request Declined';
    if (act == 'stock_request') return 'Stock Request Dispatched';
    if (act == 'stock_alert') return 'Kitchen Stock Alert';
    if (act == 'pos_order') return 'New Kitchen Order';
    if (act == 'advance_order_ticket') {
      final ev = n['event_type']?.toString() ?? '';
      if (ev.contains('Event Reservation')) return 'Event Reservation Ticket';
      return 'Advance Order Ticket';
    }
    if (act == 'event_today') return "Today's Event Scheduled!";
    if (act == 'event_reminder') return 'Upcoming Event Reminder';
    return 'Kitchen Alert';
  }

  static String _getNotificationSubtitle(Map<String, dynamic> n) {
    final act = n['action_type']?.toString() ?? '';
    final ev = n['event_type']?.toString();
    if (act == 'stock_approved') return ev ?? 'Inventory team approved your stock request.';
    if (act == 'stock_rejected') return ev ?? 'Inventory team declined your stock request.';
    if (act == 'stock_request') return 'Stock requested: ${ev ?? ''}';
    if (act == 'stock_alert') return ev ?? 'Kitchen ingredient stock is low or exhausted.';
    if (act == 'pos_order') return 'New order placed by counter staff. Ready for preparation.';
    if (act == 'advance_order_ticket') return ev ?? 'Scheduled advance order is ready for preparation.';
    if (act == 'event_today') return ev ?? 'Event reservation is scheduled for today!';
    if (act == 'event_reminder') return ev ?? 'Upcoming event reservation scheduled within 2-5 days.';
    return ev ?? 'Activity in the kitchen.';
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
        .order('created_at', ascending: false)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _posRaw = rows;
            _initialLoading = false;
            // Sync local cache
            for (final o in rows) {
              final key = 'pos_${o['id']}';
              _kitchenStatus[key] = o['kitchen_status']?.toString() ?? 'Pending';
            }
          });
        });

    _advSubscription = Supabase.instance.client
        .from('advance_orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _advRaw = rows;
            _initialLoading = false;
            // Sync local cache
            for (final o in rows) {
              final key = 'adv_${o['id']}';
              final status = o['status']?.toString().toLowerCase();
              _kitchenStatus[key] = status == 'preparing' ? 'Preparing' :
                                    status == 'ready' ? 'Ready' :
                                    status == 'done' ? 'Done' : 'Pending';
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
            // Sync local cache
            for (final o in rows) {
              final key = 'res_${o['id']}';
              _kitchenStatus[key] = o['kitchen_status']?.toString() ?? 'Pending';
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
      final ks = _kitchenStatus['pos_${o['id']}'] ?? o['kitchen_status']?.toString() ?? 'Pending';
      final ps = o['payment_status']?.toString().toLowerCase() ?? 'unpaid';
      final rs = o['refund_status']?.toString().toLowerCase() ?? 'none';
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String subtitle = '',
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final id = o['id'].toString();
    final isAdvance = o['_is_advance'] == true;
    final isReservation = o['_is_reservation'] == true;
    final statusKey = isReservation ? 'res_$id' : (isAdvance ? 'adv_$id' : 'pos_$id');
    return _KitchenOrderCard(
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
    );
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

    final now = DateTime.now();
    final List<Map<String, dynamic>> actionableOrders = [];
    final List<Map<String, dynamic>> scheduledLaterOrders = [];

    for (final o in allOrders) {
      if (o['_is_advance'] == true) {
        final pt = _getPrepareByDateTime(
          o['order_date']?.toString(),
          o['order_time']?.toString(),
        );
        final ks = o['kitchen_status']?.toString() ?? 'Pending';
        if (pt != null && now.isBefore(pt) && ks == 'Pending') {
          scheduledLaterOrders.add(o);
          continue;
        }
      }
      actionableOrders.add(o);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int cols = 1;
        if (width >= 1500) {
          cols = 5;
        } else if (width >= 1150) {
          cols = 4;
        } else if (width >= 820) {
          cols = 3;
        } else if (width >= 540) {
          cols = 2;
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── Section 1: Actionable Now (Live POS + Due Advance Orders) ──
            if (actionableOrders.isNotEmpty) ...[
              if (scheduledLaterOrders.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildSectionHeader(
                      icon: Icons.bolt_rounded,
                      title: 'ORDERS TO COOK NOW',
                      count: actionableOrders.length,
                      color: const Color(0xFF059669),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 300,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildOrderCard(actionableOrders[index]),
                    childCount: actionableOrders.length,
                  ),
                ),
              ),
            ],

            // ── Section 2: Scheduled for Later Today (Locked Advance Orders) ──
            if (scheduledLaterOrders.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, actionableOrders.isEmpty ? 12 : 20, 16, 8),
                  child: _buildSectionHeader(
                    icon: Icons.schedule_rounded,
                    title: 'UPCOMING ORDERS (FOR LATER)',
                    subtitle: '• Starts 20m before time',
                    count: scheduledLaterOrders.length,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 300,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildOrderCard(scheduledLaterOrders[index]),
                    childCount: scheduledLaterOrders.length,
                  ),
                ),
              ),
            ],

            // Bottom breathing space
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B211D), Color(0xFF133831)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Order Scheduled for Later',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
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
                  children: [
                    Text(
                      'This advance order is scheduled for later. To make sure the food is served hot and fresh, it will open for cooking 20 minutes before the scheduled time.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.5,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHEDULED TIME',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.order['order_date']} at ${_formatFriendlyTime(widget.order['order_time']?.toString())}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'COOKING STARTS AT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.alarm, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMM d, yyyy • h:mm a').format(prepTime),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF334155),
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'For Bulk Menu Orders: ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'If this advance order has many items or platters that require extra preparation time, tap ',
                                  ),
                                  TextSpan(
                                    text: 'Cook Early',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' below to start cooking immediately.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Keep Locked',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          widget.onStatusChanged('Preparing');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Advance order is now cooking! Moved to Active Orders.'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.local_fire_department_rounded, size: 16),
                        label: Text(
                          'Cook Early (Bulk)',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
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
        return minutes == 1 ? '1m ago' : '${minutes}m ago';
      } else if (elapsed.inHours < 24) {
        final hours = elapsed.inHours;
        return hours == 1 ? '1h ago' : '${hours}h ago';
      } else {
        final days = elapsed.inDays;
        return days == 1 ? '1d ago' : '${days}d ago';
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
    final isUrgent = elapsed != null && elapsed.inMinutes >= 15 && status == 'Pending';

    String countdownStr = '';
    if (isTooEarly && prepTime != null) {
      final diff = prepTime.difference(DateTime.now());
      if (diff.isNegative) {
        countdownStr = 'due now';
      } else if (diff.inHours >= 1) {
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        countdownStr = 'in ${h}h ${m}m';
      } else if (diff.inMinutes > 0) {
        countdownStr = 'in ${diff.inMinutes}m';
      } else {
        countdownStr = 'in ${diff.inSeconds}s';
      }
    }

    void showOrderDetails(BuildContext context) {
      showDialog(
        context: context,
        builder: (ctx) {
          final size = MediaQuery.of(ctx).size;
          final dialogWidth = size.width < 600 ? size.width * 0.94 : 520.0;
          final cleanPrepNotes = _cleanSpecialRequests(widget.order['preparation_notes']);
          final cleanSpecialReqs = _cleanSpecialRequests(widget.order['special_requests']);
          final cleanOrderNote = _cleanSpecialRequests(widget.order['note']);
          final displayNote = (widget.isAdvanceOrder && cleanPrepNotes.isNotEmpty)
              ? cleanPrepNotes
              : (widget.isReservation && cleanSpecialReqs.isNotEmpty)
                  ? cleanSpecialReqs
                  : cleanOrderNote;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Container(
                width: dialogWidth,
                constraints: const BoxConstraints(maxHeight: 640),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B211D), Color(0xFF133831)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6C374),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatOrderId(widget.order),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0B211D),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  customer,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  widget.isAdvanceOrder
                                      ? 'Advance Order • ${widget.order['order_type'] ?? 'Take-out'}'
                                      : (widget.isReservation
                                          ? 'Event Reservation • ${widget.order['event_type'] ?? ''}'
                                          : (widget.order['table_number']?.toString().isNotEmpty == true
                                              ? 'Dine In • Table ${widget.order['table_number']}'
                                              : 'Counter Order Slip')),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFE6C374),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Advance Order Status Ribbon in Modal
                    if (widget.isAdvanceOrder)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isTooEarly ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                          border: Border(
                            bottom: BorderSide(
                              color: isTooEarly ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isTooEarly ? Icons.lock_clock_rounded : Icons.check_circle_rounded,
                              size: 16,
                              color: isTooEarly ? const Color(0xFFD97706) : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isTooEarly
                                    ? 'Scheduled for ${_formatFriendlyTime(widget.order['order_time']?.toString())} • Opens for cooking at ${_calcPrepareTime(widget.order['order_time']?.toString())} ($countdownStr)'
                                    : 'Ready to cook • Scheduled for ${_formatFriendlyTime(widget.order['order_time']?.toString())}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isTooEarly ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Special Notes
                    if (displayNote.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note_alt_outlined, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayNote,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Items List
                    Flexible(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 14, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B211D).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF0B211D).withValues(alpha: 0.15)),
                                ),
                                child: Text(
                                  '${item['quantity'] ?? 1}×',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF0B211D),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['item_name']?.toString() ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Close',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
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
        },
      );
    }

    final isPreparing = status == 'Preparing';
    final isReady = status == 'Ready';
    final isDone = status == 'Done';
    final cleanCardNote = _cleanSpecialRequests(widget.order['note']);

    final List<Color> headerGradient = isUrgent
        ? [const Color(0xFF881337), const Color(0xFF9F1239)]
        : isPreparing
            ? [const Color(0xFF0369A1), const Color(0xFF0284C7)]
            : isReady
                ? [const Color(0xFF047857), const Color(0xFF059669)]
                : isDone
                    ? [const Color(0xFF334155), const Color(0xFF475569)]
                    : (widget.isAdvanceOrder && isTooEarly)
                        ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                        : (widget.isAdvanceOrder && !isTooEarly && status == 'Pending')
                            ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                            : [const Color(0xFF0B211D), const Color(0xFF133831)];

    final Color cardBorderColor = isUrgent
        ? const Color(0xFFEF4444)
        : isPreparing
            ? const Color(0xFF0284C7).withValues(alpha: 0.6)
            : isReady
                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                : (widget.isAdvanceOrder && isTooEarly)
                    ? const Color(0xFFCBD5E1)
                    : (widget.isAdvanceOrder && !isTooEarly && status == 'Pending')
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0);

    final double cardBorderWidth = (isUrgent || isPreparing || isReady || (widget.isAdvanceOrder && !isTooEarly && status == 'Pending'))
        ? 1.8
        : 1.0;

    return GestureDetector(
      onTap: () => showOrderDetails(context),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: (widget.isAdvanceOrder && isTooEarly) ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardBorderColor,
            width: cardBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isUrgent
                  ? const Color(0x28EF4444)
                  : (widget.isAdvanceOrder && !isTooEarly && status == 'Pending')
                      ? const Color(0x2810B981)
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: isUrgent ? 14 : ((widget.isAdvanceOrder && !isTooEarly && status == 'Pending') ? 10 : 6),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KDS Ticket Header ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: headerGradient,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: (widget.isAdvanceOrder && isTooEarly)
                        ? const Color(0x3394A3B8)
                        : const Color(0x33E6C374),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Order ID Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (widget.isAdvanceOrder && isTooEarly)
                          ? const Color(0xFF475569)
                          : const Color(0xFFE6C374),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatOrderId(widget.order),
                      style: GoogleFonts.plusJakartaSans(
                        color: (widget.isAdvanceOrder && isTooEarly)
                            ? Colors.white
                            : const Color(0xFF0B211D),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Order Info & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Explicit Order Type Badges
                            Flexible(
                              fit: FlexFit.loose,
                              child: widget.isAdvanceOrder
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isTooEarly
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                            : const Color(0xFF10B981).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isTooEarly
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                              : const Color(0xFF34D399),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          isTooEarly ? 'ADVANCE' : 'ADV READY',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isTooEarly ? const Color(0xFFFDE68A) : const Color(0xFF6EE7B7),
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    )
                                  : widget.isReservation
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFA78BFA), width: 0.8),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'EVENT',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFFDDD6FE),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: const Color(0xFF34D399).withValues(alpha: 0.7),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'POS ORDER',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFF6EE7B7),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.isAdvanceOrder
                              ? (isTooEarly
                                  ? 'Today • Scheduled for ${_formatFriendlyTime(widget.order['order_time']?.toString())}'
                                  : 'Scheduled ${_formatFriendlyTime(widget.order['order_time']?.toString())} • Ready to cook!')
                              : (widget.isReservation
                                  ? 'Event • ${widget.order['event_type'] ?? ''}'
                                  : (widget.order['table_number']?.toString().isNotEmpty == true
                                      ? 'Dine In • Table ${widget.order['table_number']}'
                                      : 'Take-out Order')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: (widget.isAdvanceOrder && isTooEarly)
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFFE6C374),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Timer or Lock Badge
                  if (widget.isAdvanceOrder && isTooEarly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 10, color: Color(0xFFFCD34D)),
                          const SizedBox(width: 3),
                          Text(
                            countdownStr.isNotEmpty ? countdownStr : 'Locked',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFCD34D),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUrgent
                            ? const Color(0xFFEF4444)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUrgent ? Colors.white : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUrgent ? Icons.local_fire_department_rounded : Icons.timer_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            elapsedStr,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: isUrgent ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Order State Ribbon (Below Header) ─────────
            if (widget.isAdvanceOrder && isTooEarly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  border: Border(bottom: BorderSide(color: Color(0xFFFCD34D))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 13, color: Color(0xFFB45309)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'SCHEDULED PICKUP: ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF92400E),
                                letterSpacing: 0.2,
                              ),
                            ),
                            TextSpan(
                              text: '${_formatFriendlyTime(widget.order['order_time']?.toString())} (${widget.order['order_type'] ?? 'Take-out'})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.isAdvanceOrder && !isTooEarly && status == 'Pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  border: Border(bottom: BorderSide(color: Color(0xFFA7F3D0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'READY TO COOK • Pickup: ${_formatFriendlyTime(widget.order['order_time']?.toString())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!widget.isAdvanceOrder && !widget.isReservation && isUrgent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  border: Border(bottom: BorderSide(color: Color(0xFFFECACA))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'HIGH PRIORITY: Waiting $elapsedStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Items List ────────────────────────────────
            Expanded(
              child: Container(
                color: (widget.isAdvanceOrder && isTooEarly)
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFFFAFAFA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Loading items…',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B211D).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFF0B211D).withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    '${item['quantity']}×',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF0B211D),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['item_name']?.toString() ?? '—',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF0F172A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Special Note Callout
                      if (cleanCardNote.isNotEmpty) ...[
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
                              const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cleanCardNote,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF92400E),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (nextStatus != null)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: isTooEarly
                            ? OutlinedButton(
                                onPressed: () => _showPrepTimeRestrictedDialog(context, prepTime),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFFBEB),
                                  foregroundColor: const Color(0xFF92400E),
                                  side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'COOK AT ${_calcPrepareTime(widget.order['order_time']?.toString())}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Options',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 9,
                                              color: const Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          const Icon(Icons.chevron_right_rounded, size: 11, color: Color(0xFFB45309)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () => widget.onStatusChanged(nextStatus),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: nextStatus == 'Preparing'
                                      ? const Color(0xFF0284C7)
                                      : nextStatus == 'Ready'
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: Icon(
                                  _nextStatusIcon(nextStatus),
                                  size: 16,
                                ),
                                label: Text(
                                  nextStatus == 'Preparing'
                                      ? (widget.isAdvanceOrder ? 'START PREPARATION' : 'START PREP')
                                      : nextStatus == 'Ready'
                                          ? 'MARK READY'
                                          : 'SERVE ORDER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                    letterSpacing: 0.3,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
//  UPCOMING EVENTS NOTICE MODAL (2 TO 5 DAYS AHEAD)
// ══════════════════════════════════════════════════════════
class _UpcomingEventsNoticeDialog extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final VoidCallback onViewEventsTab;

  const _UpcomingEventsNoticeDialog({
    required this.events,
    required this.onViewEventsTab,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 680 ? 640.0 : screenWidth * 0.94;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Section with Dark Green & Gold Accent ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B211D), Color(0xFF133831)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0x33E6C374), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C374).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE6C374).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFFE6C374),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'UPCOMING EVENTS NOTICE',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6C374),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${events.length} ${events.length == 1 ? 'EVENT' : 'EVENTS'}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF0B211D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upcoming booked events in 2 to 5 days requiring preparation',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFCBD5E1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Alert Notice Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              color: const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please verify upcoming menu selections and coordinate ingredient prep or inventory requests.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF92400E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Events List ──
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _buildEventItemCard(context, event);
                },
              ),
            ),

            // ── Footer Action Area ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Dismiss',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onViewEventsTab();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.event_note_rounded, size: 18),
                      label: Text(
                        'View in Events Tab',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
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

  Widget _buildEventItemCard(BuildContext context, Map<String, dynamic> event) {
    final customerName = event['customer_name']?.toString() ?? 'Guest';
    final eventType = event['event_type']?.toString() ?? 'Event';
    final eventDateStr = event['event_date']?.toString() ?? '';
    final startTime = event['start_time']?.toString() ?? '';
    final guestCount = event['number_of_guests'];
    final menuItems = event['selected_menu_items'] as Map<String, dynamic>? ?? {};
    final specialRequests = _cleanSpecialRequests(event['special_requests']);

    // Calculate days until
    int daysUntil = 0;
    String formattedDate = eventDateStr;
    DateTime parsedDate = DateTime.now();
    try {
      parsedDate = DateTime.parse(eventDateStr);
      formattedDate = DateFormat('EEE, MMM d, yyyy').format(parsedDate);
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final eventDateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      daysUntil = eventDateOnly.difference(todayDate).inDays;
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(parsedDate).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(parsedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              eventType,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          if (guestCount != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $guestCount guests',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Countdown Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    'In $daysUntil days',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFC2410C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date & Time
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  '$formattedDate at $formattedTime',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (menuItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: menuItems.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${entry.value}×',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          entry.key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (specialRequests.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Note: $specialRequests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          final filtered = rows.where((r) {
            final isMenuBased = r['is_menu_based'] == true;
            final ps = r['payment_status']?.toString().toLowerCase();
            final isPaid = ps == 'paid' || ps == 'deposit_paid' || ps == 'fully_paid';
            final menuItems = r['selected_menu_items'];
            final hasMenu = menuItems != null && (menuItems as Map).isNotEmpty;
            final isNotServed = r['kitchen_status']?.toString() != 'Done';
            // Only show events that have been approved by admin in Payment Approvals
            final status = r['status']?.toString().toLowerCase();
            final isApproved = status == 'confirmed' || status == 'completed';
            return isMenuBased && isPaid && hasMenu && isNotServed && isApproved;
          }).toList();
          setState(() {
            _events = filtered;
            _loading = false;
          });
          // Check and send 2-day reminder notifications if any event meets criteria
          NotificationService.checkAndSendUpcomingEventReminders();
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
        if (width >= 1260) {
          crossAxisCount = 3;
        } else if (width >= 780) {
          crossAxisCount = 2;
        }

        if (crossAxisCount > 1) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 385, // Generous height for uniform grid without inner cramps
            ),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index];
              return _UpcomingEventCard(
                key: ValueKey(event['id']?.toString() ?? index.toString()),
                event: event,
              );
            },
          );
        }

        // Single column view for mobile/narrow screens
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            final event = _events[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _UpcomingEventCard(
                key: ValueKey(event['id']?.toString() ?? index.toString()),
                event: event,
              ),
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

  const _UpcomingEventCard({super.key, required this.event});

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

  @override
  void didUpdateWidget(covariant _UpcomingEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event['id'] != oldWidget.event['id'] ||
        widget.event['kitchen_status'] != oldWidget.event['kitchen_status']) {
      _kitchenStatus = widget.event['kitchen_status']?.toString() ?? 'Pending';
      _isLoading = false;
    }
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
    final specialRequests = _cleanSpecialRequests(widget.event['special_requests']);

    // Parse event date
    String formattedDate = eventDateStr;
    int daysUntil = 0;
    try {
      final eventDate = DateTime.parse(eventDateStr);
      formattedDate = DateFormat('EEE, MMM d, yyyy').format(eventDate);
      
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
      daysUntil = eventDateOnly.difference(todayDate).inDays;
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
    IconData urgencyIcon;
    String urgencyLabel;
    if (daysUntil < 0) {
      urgencyBg = const Color(0xFFE2E8F0);
      urgencyTextColor = const Color(0xFF475569);
      urgencyIcon = Icons.history_rounded;
      urgencyLabel = 'Passed';
    } else if (daysUntil == 0) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyTextColor = const Color(0xFFDC2626);
      urgencyIcon = Icons.notification_important_rounded;
      urgencyLabel = 'Today!';
    } else if (daysUntil == 1) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyTextColor = const Color(0xFFDC2626);
      urgencyIcon = Icons.warning_amber_rounded;
      urgencyLabel = 'Tomorrow!';
    } else if (daysUntil <= 3) {
      urgencyBg = const Color(0xFFFFEDD5);
      urgencyTextColor = const Color(0xFFEA580C);
      urgencyIcon = Icons.schedule_rounded;
      urgencyLabel = 'In $daysUntil days';
    } else if (daysUntil <= 7) {
      urgencyBg = const Color(0xFFFEF9C3);
      urgencyTextColor = const Color(0xFFCA8A04);
      urgencyIcon = Icons.calendar_today_rounded;
      urgencyLabel = 'In $daysUntil days';
    } else {
      urgencyBg = const Color(0xFFDCFCE7);
      urgencyTextColor = const Color(0xFF16A34A);
      urgencyIcon = Icons.event_available_rounded;
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
              ? const Color(0xFF10B981)
              : isReady
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFE2E8F0),
          width: (isDone || isReady) ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : isReady
                    ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                // Calendar Date Badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B211D), Color(0xFF133831)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(DateTime.tryParse(eventDateStr) ?? DateTime.now()).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE6C374),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(DateTime.tryParse(eventDateStr) ?? DateTime.now()),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B211D).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              eventType,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B211D),
                              ),
                            ),
                          ),
                          if (guestCount != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $guestCount guests',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: urgencyTextColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(urgencyIcon, size: 12, color: urgencyTextColor),
                      const SizedBox(width: 4),
                      Text(
                        urgencyLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: urgencyTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body Content ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time info row
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '$formattedDate at $formattedTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Menu Selection Header
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'MENU SELECTION',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Menu Items Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: menuItems.entries.map((entry) {
                      final qty = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B211D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$qty×',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFE6C374),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF92400E),
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
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFFA7F3D0)
                          : (isReady ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : (isReady ? Icons.outdoor_grill_rounded : Icons.timer_outlined),
                        size: 13,
                        color: isDone
                            ? const Color(0xFF16A34A)
                            : (isReady ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _kitchenStatus.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF16A34A)
                              : (isReady ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Action Button
                if (!isDone)
                  Tooltip(
                    message: !isEventDay ? 'Preparation unlocked on event date ($formattedDate)' : '',
                    child: ElevatedButton.icon(
                      onPressed: (!isEventDay || _isLoading) ? null : _advanceStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isEventDay
                            ? const Color(0xFF94A3B8)
                            : (isReady ? const Color(0xFF059669) : const Color(0xFF0284C7)),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
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
  static const int _itemsPerPage = 25;
  int _selectedFilter = 0; // 0: All, 1: Regular, 2: Advance, 3: Events
  String _searchQuery = '';
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  final List<String> _filterLabels = ['All Orders', 'Dine-In & Takeout', 'Advance Orders', 'Events & Catering'];
  final List<IconData> _filterIcons = [
    Icons.restaurant_menu_rounded,
    Icons.receipt_long_rounded,
    Icons.schedule_rounded,
    Icons.celebration_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchDoneOrders();
  }

  void _reloadOrders() {
    setState(() {
      _ordersFuture = _fetchDoneOrders();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchDoneOrders() async {
    final List<Map<String, dynamic>> result = [];

    // 1. Fetch regular POS orders
    try {
      final ordersRaw = await Supabase.instance.client
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> posDoneOrders = [];
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
          posDoneOrders.add(o);
        }
      }

      // Batch fetch order_items for finished POS orders
      final orderIds = posDoneOrders.map((o) => o['id'].toString()).toList();
      final Map<String, List<Map<String, dynamic>>> itemsByOrderId = {};

      if (orderIds.isNotEmpty) {
        try {
          // Batch fetch in safe chunks of 50 to avoid HTTP 414 URI Too Long with 900+ IDs
          const chunkSize = 50;
          final List<List<String>> chunks = [];
          for (var i = 0; i < orderIds.length; i += chunkSize) {
            chunks.add(orderIds.sublist(
              i,
              (i + chunkSize > orderIds.length) ? orderIds.length : i + chunkSize,
            ));
          }

          final results = await Future.wait(
            chunks.map(
              (c) => Supabase.instance.client
                  .from('order_items')
                  .select('order_id, item_name, quantity, unit_price')
                  .inFilter('order_id', c),
            ),
          );

          for (final itemsRaw in results) {
            for (final it in itemsRaw) {
              final oid = it['order_id']?.toString() ?? '';
              if (oid.isNotEmpty) {
                itemsByOrderId.putIfAbsent(oid, () => []).add({
                  'item_name': it['item_name'] ?? 'Dish Item',
                  'name': it['item_name'] ?? 'Dish Item',
                  'quantity': it['quantity'] ?? 1,
                  'price': it['unit_price'] ?? 0.0,
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Error batch fetching order items: $e');
        }
      }

      for (final o in posDoneOrders) {
        final oid = o['id'].toString();
        result.add({
          ...o,
          '_is_advance': false,
          '_is_reservation': false,
          'items': itemsByOrderId[oid] ?? (o['items'] is List ? o['items'] : []),
        });
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
          final resPrice = (r['total_price'] ?? r['total_amount'] ?? r['package_price'] ?? r['deposit_amount'] ?? 0.0) is num
              ? (r['total_price'] ?? r['total_amount'] ?? r['package_price'] ?? r['deposit_amount'] ?? 0.0).toDouble()
              : double.tryParse(r['total_price']?.toString() ?? '') ?? 0.0;

          result.add({
            ...r,
            '_is_advance': false,
            '_is_reservation': true,
            'kitchen_status': 'Done',
            'customer_name': r['customer_name'] ?? 'Event Guest',
            'created_at': r['event_date'],
            'total_price': resPrice,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reservation finished orders: $e');
    }

    // Sort by creation time descending
    result.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return result;
  }

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> allOrders) {
    List<Map<String, dynamic>> filtered = allOrders;

    // Filter by type
    switch (_selectedFilter) {
      case 1: // Regular
        filtered = filtered.where((o) => o['_is_reservation'] != true && o['_is_advance'] != true).toList();
        break;
      case 2: // Advance
        filtered = filtered.where((o) => o['_is_advance'] == true).toList();
        break;
      case 3: // Events
        filtered = filtered.where((o) => o['_is_reservation'] == true).toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((o) {
        final cust = (o['customer_name'] ?? '').toString().toLowerCase();
        final id = (o['id'] ?? '').toString().toLowerCase();
        final txn = (o['transaction_id'] ?? '').toString().toLowerCase();
        final table = (o['table_number'] ?? '').toString().toLowerCase();
        final eventType = (o['event_type'] ?? '').toString().toLowerCase();
        final orderType = (o['order_type'] ?? '').toString().toLowerCase();

        return cust.contains(q) ||
            id.contains(q) ||
            txn.contains(q) ||
            table.contains(q) ||
            eventType.contains(q) ||
            orderType.contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE6C374)),
          );
        }
        final allOrders = snap.data ?? [];
        final filteredOrders = _filterOrders(allOrders);

        // Counts per filter category
        final counts = [
          allOrders.length,
          allOrders.where((o) => o['_is_reservation'] != true && o['_is_advance'] != true).length,
          allOrders.where((o) => o['_is_advance'] == true).length,
          allOrders.where((o) => o['_is_reservation'] == true).length,
        ];

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

        return Column(
          children: [
            // ── Top Bar with Metrics & Search ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF081815), Color(0xFF102D26)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Metric Cards Row
                  Row(
                    children: List.generate(_filterLabels.length, (index) {
                      final isSelected = _selectedFilter == index;
                      final accentColor = index == 1
                          ? const Color(0xFF10B981)
                          : (index == 2
                              ? const Color(0xFF38BDF8)
                              : (index == 3 ? const Color(0xFFA78BFA) : const Color(0xFFE6C374)));

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedFilter = index;
                            _currentPage = 1;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.08),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.20),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(_filterIcons[index], size: 15, color: accentColor),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _filterLabels[index],
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 10.5,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        NumberFormat('#,###').format(counts[index]),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isSelected ? accentColor : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
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
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Search & Toolbar Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: TextField(
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 1;
                            }),
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Search order #, customer name, table number, or event type...',
                              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE6C374), size: 17),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 15),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => setState(() {
                                        _searchQuery = '';
                                        _currentPage = 1;
                                      }),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh button
                      InkWell(
                        onTap: _reloadOrders,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6C374).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.refresh_rounded, color: Color(0xFFE6C374), size: 15),
                              const SizedBox(width: 6),
                              Text(
                                'Refresh',
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C374), fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Main Content Area: Responsive Data Table ──
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B211D).withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_rounded, size: 38, color: Color(0xFF0B211D)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'No orders match "$_searchQuery"' : 'No finished orders in this category',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed kitchen tickets will automatically appear here with full recipe breakdown.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF1F5F4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LayoutBuilder(
                            builder: (context, tableConstraints) {
                              final needHScroll = tableConstraints.maxWidth < 840;
                              final Widget tableCore = Column(
                                children: [
                                  // ── Table Header ──
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0B211D),
                                      border: Border(bottom: BorderSide(color: Color(0x33E6C374))),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'ORDER #',
                                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C374), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'CUSTOMER & DINING',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            'PREPARED DISHES / ITEMS',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'DATE & TIME',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'AMOUNT',
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'STATUS',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 75,
                                          child: Text(
                                            'ACTION',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C374), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── Table Body Rows ──
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: currentOrders.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, i) {
                                        return _FinishedOrderTableRow(
                                          order: currentOrders[i],
                                          isEven: i % 2 == 0,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );

                              if (needHScroll) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 840,
                                    child: tableCore,
                                  ),
                                );
                              }
                              return tableCore;
                            },
                          ),
                        ),
                      ),
                    ),
            ),

            // ── Clean Floating Pagination Footer ──
            if (totalPages > 1) _buildPagination(totalPages, filteredOrders.length),
          ],
        );
      },
    );
  }

  Widget _buildPagination(int totalPages, int totalItems) {
    List<Widget> pageWidgets = [];
    bool lastWasEllipsis = false;

    for (int i = 1; i <= totalPages; i++) {
      if (totalPages <= 7 || i == 1 || i == totalPages || (i >= _currentPage - 2 && i <= _currentPage + 2)) {
        final isSelected = i == _currentPage;
        pageWidgets.add(
          GestureDetector(
            onTap: () => setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0B211D) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0B211D) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0B211D).withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$i',
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? const Color(0xFFE6C374) : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        );
        lastWasEllipsis = false;
      } else {
        if (!lastWasEllipsis) {
          pageWidgets.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
          ));
          lastWasEllipsis = true;
        }
      }
    }

    final start = (_currentPage - 1) * _itemsPerPage + 1;
    final end = (_currentPage * _itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of ${NumberFormat('#,###').format(totalItems)} tickets',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              _buildNavButton(
                label: 'Prev',
                icon: Icons.chevron_left_rounded,
                isEnabled: _currentPage > 1,
                onTap: () => setState(() => _currentPage--),
              ),
              const SizedBox(width: 6),
              ...pageWidgets,
              const SizedBox(width: 6),
              _buildNavButton(
                label: 'Next',
                icon: Icons.chevron_right_rounded,
                isEnabled: _currentPage < totalPages,
                onTap: () => setState(() => _currentPage++),
                isTrailing: true,
              ),
            ],
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isEnabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailing) Icon(icon, color: isEnabled ? const Color(0xFF0F2C27) : const Color(0xFF94A3B8), size: 14),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isEnabled ? const Color(0xFF0F2C27) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            if (isTrailing) Icon(icon, color: isEnabled ? const Color(0xFF0F2C27) : const Color(0xFF94A3B8), size: 14),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  REALISTIC FINISHED ORDER TABLE ROW
// ══════════════════════════════════════════════════════════
class _FinishedOrderTableRow extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isEven;

  const _FinishedOrderTableRow({required this.order, required this.isEven});

  @override
  State<_FinishedOrderTableRow> createState() => _FinishedOrderTableRowState();
}

class _FinishedOrderTableRowState extends State<_FinishedOrderTableRow> {
  late List<Map<String, dynamic>> _items;
  bool _isLoadingFallback = false;

  @override
  void initState() {
    super.initState();
    _items = _extractOrderItems();
    if (_items.isEmpty && widget.order['_is_reservation'] != true && widget.order['_is_advance'] != true) {
      _loadItemsFallback();
    }
  }

  @override
  void didUpdateWidget(covariant _FinishedOrderTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['id'] != widget.order['id']) {
      _items = _extractOrderItems();
      if (_items.isEmpty && widget.order['_is_reservation'] != true && widget.order['_is_advance'] != true) {
        _loadItemsFallback();
      }
    }
  }

  Future<void> _loadItemsFallback() async {
    final orderId = widget.order['id']?.toString() ?? '';
    if (orderId.isEmpty || _isLoadingFallback) return;
    _isLoadingFallback = true;
    try {
      final rows = await Supabase.instance.client
          .from('order_items')
          .select('item_name, quantity, unit_price')
          .eq('order_id', orderId);
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _items = rows.map((it) => {
            'item_name': it['item_name'] ?? 'Dish Item',
            'name': it['item_name'] ?? 'Dish Item',
            'quantity': it['quantity'] ?? 1,
            'price': it['unit_price'] ?? 0.0,
          }).toList();
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _extractOrderItems() {
    final List<Map<String, dynamic>> itemsList = [];

    final dynamic rawItems = widget.order['items'] ?? widget.order['order_items'];
    if (rawItems is List) {
      for (var it in rawItems) {
        if (it is Map) {
          itemsList.add({
            'name': (it['name'] ?? it['item_name'] ?? it['dish_name'] ?? 'Dish Item').toString(),
            'quantity': (it['quantity'] ?? it['qty'] ?? 1) as num,
            'price': (it['price'] ?? it['unit_price'] ?? 0.0) as num,
            'notes': (it['notes'] ?? it['special_instructions'] ?? '').toString(),
          });
        } else if (it is String) {
          itemsList.add({'name': it, 'quantity': 1, 'price': 0.0, 'notes': ''});
        }
      }
    }

    final dynamic menuItems = widget.order['selected_menu_items'];
    if (menuItems is Map) {
      menuItems.forEach((key, val) {
        int qty = 1;
        if (val is num) {
          qty = val.toInt();
        } else if (val is Map) {
          qty = (val['quantity'] as num?)?.toInt() ?? 1;
        } else if (val is String) {
          qty = int.tryParse(val) ?? 1;
        }
        itemsList.add({'name': key.toString(), 'quantity': qty, 'price': 0.0, 'notes': ''});
      });
    } else if (menuItems is List) {
      for (var it in menuItems) {
        if (it is Map) {
          itemsList.add({
            'name': (it['name'] ?? it['item_name'] ?? 'Dish Item').toString(),
            'quantity': (it['quantity'] ?? 1) as num,
            'price': (it['price'] ?? 0.0) as num,
            'notes': (it['notes'] ?? '').toString(),
          });
        } else if (it is String) {
          itemsList.add({'name': it, 'quantity': 1, 'price': 0.0, 'notes': ''});
        }
      }
    }

    return itemsList;
  }

  void _showOrderDetailsModal(BuildContext context, List<Map<String, dynamic>> items, String orderId, String customer, String timeStr, double? total, String badgeText, Color statusBg, IconData statusIcon, Color accentColor, bool isReservation, bool isAdvance) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 540 ? 500.0 : screenWidth * 0.94;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B211D), Color(0xFF133831)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0x33E6C374), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6C374).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE6C374), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KITCHEN TICKET: $orderId',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$customer • $timeStr',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C374), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Dishes & Recipe Items List
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  children: [
                    Text(
                      'PREPARED DISHES & RECIPES',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          isReservation
                              ? 'Standard Chef Set Menu (Dishes logged under catering schedule)'
                              : 'No item breakdown logged for this order',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ...items.map((it) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B211D),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${it['quantity']}x',
                                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C374), fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it['name']?.toString() ?? 'Dish',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF1E293B)),
                                    ),
                                    if ((it['notes'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Note: ${it['notes']}',
                                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDC2626), fontSize: 10.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if ((it['price'] as num) > 0)
                                Text(
                                  '₱${NumberFormat('#,##0.00').format(it['price'])}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: const Color(0xFF0F2C27),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 10),
                    if (total != null && total > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B211D).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0B211D).withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL TICKET AMOUNT',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF0F2C27)),
                            ),
                            Text(
                              '₱${NumberFormat('#,##0.00').format(total)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: const Color(0xFF0F2C27),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Close Button
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B211D),
                      foregroundColor: const Color(0xFFE6C374),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0x66E6C374)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Text('Close Ticket', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isEven = widget.isEven;
    final items = _items;

    final isAdvance = order['_is_advance'] == true;
    final isReservation = order['_is_reservation'] == true;

    final orderId = isReservation
        ? (order['id'] != null ? 'EVENT #${order['id'].toString().substring(0, 5).toUpperCase()}' : 'EVENT')
        : (isAdvance
            ? (order['id'] != null ? 'ADV #${order['id'].toString().substring(0, 5).toUpperCase()}' : 'ADVANCE')
            : _formatOrderId(order));

    final customer = order['customer_name']?.toString() ?? 'Guest';
    final total = (order['total_price'] ?? order['total_amount'] ?? 0.0) is num
        ? (order['total_price'] ?? order['total_amount'] ?? 0.0).toDouble()
        : double.tryParse(order['total_price']?.toString() ?? '') ?? 0.0;

    final createdAt = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())
        : null;

    String timeStr;
    if (isReservation) {
      if (order['event_date'] != null) {
        final d = DateTime.tryParse(order['event_date'].toString());
        timeStr = d != null ? DateFormat('MMM d, yyyy').format(d) : order['event_date'].toString();
      } else {
        timeStr = '—';
      }
    } else if (isAdvance) {
      timeStr = '${order['order_date'] ?? ''} ${order['order_time'] ?? ''}'.trim();
      if (timeStr.isEmpty) timeStr = '—';
    } else {
      timeStr = createdAt != null ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal()) : '—';
    }

    final tableNumber = order['table_number']?.toString();
    final orderType = isReservation
        ? (order['event_type']?.toString())
        : order['order_type']?.toString();
    final numberOfGuests = order['number_of_guests'];

    // Accent color coding
    final Color accentColor = isReservation
        ? const Color(0xFF7C3AED)
        : (isAdvance ? const Color(0xFF0284C7) : const Color(0xFF059669));

    // Status info
    final rs = order['refund_status']?.toString() ?? 'none';
    final statusStr = order['status']?.toString().toLowerCase() ?? '';
    final isRefunded = rs == 'full_refund' || rs == 'partial_refund' || statusStr == 'refunded' || statusStr == 'cancelled';
    final badgeText = (rs == 'full_refund' || statusStr == 'refunded')
        ? 'REFUNDED'
        : (statusStr == 'cancelled' ? 'CANCELLED' : 'SERVED');
    final Color statusBg = isRefunded
        ? (statusStr == 'cancelled' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))
        : const Color(0xFF10B981);
    final IconData statusIcon = isRefunded ? Icons.cancel_outlined : Icons.check_circle_rounded;

    // Use _items directly
    return Material(
      color: isEven ? Colors.white : const Color(0xFFFBFDFD),
      child: InkWell(
        onTap: () => _showOrderDetailsModal(context, items, orderId, customer, timeStr, total, badgeText, statusBg, statusIcon, accentColor, isReservation, isAdvance),
        hoverColor: const Color(0xFFE6C374).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Order ID & Type Badge
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReservation ? Icons.celebration_rounded : (isAdvance ? Icons.schedule_rounded : Icons.restaurant_rounded),
                            size: 11,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            orderId,
                            style: GoogleFonts.plusJakartaSans(
                              color: accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Customer & Dining / Table Details
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF0F2C27)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (tableNumber != null && tableNumber.isNotEmpty)
                          _tableSubTag(Icons.table_restaurant_outlined, 'T-$tableNumber'),
                        if (numberOfGuests != null)
                          _tableSubTag(Icons.people_outline_rounded, '$numberOfGuests pax'),
                        if (orderType != null && orderType.isNotEmpty)
                          _tableSubTag(
                            isReservation ? Icons.event_note_rounded : Icons.room_service_outlined,
                            orderType,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Prepared Dishes & Items List
              Expanded(
                flex: 4,
                child: items.isEmpty
                    ? Text(
                        isReservation ? 'Event / Set Menu' : 'No items recorded',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          ...items.take(2).map((it) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${it['quantity']}x ${it['name']}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          if (items.length > 2)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6C374).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                '+${items.length - 2}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFFB45309)),
                              ),
                            ),
                        ],
                      ),
              ),

              // 4. Completed Date & Time
              Expanded(
                flex: 2,
                child: Text(
                  timeStr,
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),

              // 5. Total Amount
              Expanded(
                flex: 2,
                child: Text(
                  total > 0 ? '₱${NumberFormat('#,##0.00').format(total)}' : '—',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F2C27),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // 6. Status Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusBg.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusBg, size: 11),
                        const SizedBox(width: 3.5),
                        Text(
                          badgeText,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusBg,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 7. Action: View Ticket
              SizedBox(
                width: 75,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B211D).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0B211D).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 11.5, color: Color(0xFF0B211D)),
                        const SizedBox(width: 3),
                        Text(
                          'Ticket',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0B211D), fontWeight: FontWeight.w800, fontSize: 10),
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
    );
  }

  Widget _tableSubTag(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.5, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
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
  static const int _itemsPerPage = 15;

  // Form controllers
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  String _selectedUnit = '';
  String _selectedPriority = 'Low';
  String _historyFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  bool _submitting = false;

  static const _priorities = [
    ('Low', 'Standard Replenish', Icons.check_circle_outline_rounded, Color(0xFF10B981)),
    ('Urgent', 'Immediate / Critical', Icons.warning_amber_rounded, Color(0xFFEF4444)),
  ];

  List<String> _availableItems = [];
  Map<String, String> _itemUnits = {};
  Map<String, int> _itemStocks = {};

  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
    _itemCtrl.addListener(_onItemChanged);
  }

  @override
  void dispose() {
    _itemCtrl.removeListener(_onItemChanged);
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _resetUnit() {
    setState(() {
      _selectedUnit = '';
      _unitCtrl.text = '';
    });
  }

  void _onItemChanged() {
    final itemName = _itemCtrl.text.trim();

    if (_itemUnits.containsKey(itemName)) {
      setState(() {
        _selectedUnit = _itemUnits[itemName]!;
        _unitCtrl.text = _selectedUnit;
      });
    } else {
      _resetUnit();
    }

    if (itemName.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    } else {
      final matches = _availableItems
          .where((item) => item.toLowerCase().contains(itemName.toLowerCase()))
          .take(6)
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

  Future<void> _submitRequest() async {
    final itemName = _itemCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim());

    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Please specify an ingredient name'),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_availableItems.contains(itemName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$itemName" is not listed in Main Inventory. Please select from available items.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid requested quantity (> 0)'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final availableStock = _itemStocks[itemName] ?? 0;
    if (qty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot request $qty $itemName. Only $availableStock ${_itemUnits[itemName] ?? 'pcs'} currently available in Main Inventory.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

      // Send real-time notification to Pagsanjan Inventory team
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: chef.split('@')[0],
        actionType: 'stock_request',
        reservationId: 'N/A',
        eventType: '$itemName ($qty $_selectedUnit)',
      );

      if (mounted) {
        _itemCtrl.clear();
        _qtyCtrl.clear();
        _noteCtrl.clear();
        setState(() {
          _resetUnit();
          _selectedPriority = 'Low';
          _submitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Stock Request for $itemName dispatched to Inventory!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('kitchen_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snap) {
        final allRequests = snap.data ?? [];
        final pendingCount = allRequests.where((r) => r['status'] == 'Pending').length;
        final approvedCount = allRequests.where((r) => r['status'] == 'Approved').length;
        final urgentCount = allRequests.where((r) => r['priority'] == 'Urgent' && r['status'] == 'Pending').length;

        // Filtered list
        final filteredRequests = _historyFilter == 'All'
            ? allRequests
            : allRequests.where((r) => r['status'] == _historyFilter).toList();

        final int totalPages = (filteredRequests.length / _itemsPerPage).ceil();
        if (_currentPage > totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentPage = totalPages);
          });
        }
        final int startIndex = (_currentPage - 1) * _itemsPerPage;
        int endIndex = startIndex + _itemsPerPage;
        if (endIndex > filteredRequests.length) endIndex = filteredRequests.length;
        final currentRequests = (startIndex < filteredRequests.length)
            ? filteredRequests.sublist(startIndex, endIndex)
            : <Map<String, dynamic>>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI Summary Cards ────────────────────────
                  _buildSummaryBar(
                    total: allRequests.length,
                    pending: pendingCount,
                    approved: approvedCount,
                    urgent: urgentCount,
                  ),
                  const SizedBox(height: 18),

                  // ── Main Requisition Form Card ───────────────
                  _buildRequisitionCard(),
                  const SizedBox(height: 28),

                  // ── Request History Section ──────────────────
                  _buildHistoryHeader(
                    total: allRequests.length,
                    pending: pendingCount,
                    approved: approvedCount,
                  ),
                  const SizedBox(height: 14),

                  if (snap.connectionState == ConnectionState.waiting && allRequests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: Color(0xFFD97706)),
                      ),
                    )
                  else if (filteredRequests.isEmpty)
                    _buildEmptyState(
                      Icons.inventory_2_outlined,
                      'No ${_historyFilter == 'All' ? '' : '$_historyFilter '}Stock Requests',
                      _historyFilter == 'All'
                          ? 'Fill out the form above to request ingredients from Main Inventory.'
                          : 'No stock requests currently match the "$_historyFilter" filter.',
                    )
                  else ...[
                    ...currentRequests.map((r) => _RealisticRequestCard(request: r)),
                    if (totalPages > 1) _buildPagination(totalPages),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 1. KPI Top Summary Bar ─────────────────────────────────
  Widget _buildSummaryBar({
    required int total,
    required int pending,
    required int approved,
    required int urgent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatMetric(
              title: 'Total Requisitions',
              value: '$total',
              icon: Icons.assignment_outlined,
              iconColor: const Color(0xFF64748B),
              bgColor: Colors.white,
              width: isMobile ? double.infinity : (constraints.maxWidth - 36) / 4,
            ),
            _buildStatMetric(
              title: 'Pending Dispatch',
              value: '$pending',
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              width: isMobile ? double.infinity : (constraints.maxWidth - 36) / 4,
            ),
            _buildStatMetric(
              title: 'Approved by Inventory',
              value: '$approved',
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFFA7F3D0),
              width: isMobile ? double.infinity : (constraints.maxWidth - 36) / 4,
            ),
            _buildStatMetric(
              title: 'Urgent Priority',
              value: '$urgent',
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFECACA),
              width: isMobile ? double.infinity : (constraints.maxWidth - 36) / 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Color? borderColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Requisition Form Card ───────────────────────────────
  Widget _buildRequisitionCard() {
    final quickItems = [
      'Broccoli Flower',
      'Fresh Egg',
      'Chicken Breast',
      'Pork Belly',
      'Cooking Oil',
      'White Rice',
      'Garlic',
      'Onion',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B211D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.kitchen_rounded,
                    color: Color(0xFFE6C374),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Ingredients from Main Inventory',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Direct line to Pagsanjan Inventory dispatch. Items will be transferred upon approval.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Suggestion Chips
                Text(
                  'QUICK POPULAR INGREDIENTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: quickItems.map((item) {
                      final isSelected = _itemCtrl.text.trim().toLowerCase() == item.toLowerCase();
                      final isAvailable = _availableItems.any((i) => i.toLowerCase() == item.toLowerCase());
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            size: 15,
                            color: isSelected ? const Color(0xFF0B211D) : const Color(0xFF64748B),
                          ),
                          label: Text(item),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF0B211D) : const Color(0xFF334155),
                          ),
                          backgroundColor: isSelected
                              ? const Color(0xFFE6C374).withValues(alpha: 0.35)
                              : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: isAvailable ? () => _selectSuggestion(item) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Item Name with Dropdown Autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernField(
                      controller: _itemCtrl,
                      label: 'Ingredient Name',
                      hintText: 'Search or type ingredient name (e.g. Broccoli Flower)...',
                      icon: Icons.inventory_2_outlined,
                      suffixIcon: _itemCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _itemCtrl.clear();
                                _resetUnit();
                              },
                            )
                          : null,
                    ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _suggestions.map((suggestion) {
                            final unit = _itemUnits[suggestion] ?? 'pcs';
                            final stock = _itemStocks[suggestion] ?? 0;
                            return InkWell(
                              onTap: () => _selectSuggestion(suggestion),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.shopping_basket_outlined, size: 16, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        suggestion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: stock > 10
                                            ? const Color(0xFFECFDF5)
                                            : stock > 0
                                                ? const Color(0xFFFFFBEB)
                                                : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: stock > 10
                                              ? const Color(0xFFA7F3D0)
                                              : stock > 0
                                                  ? const Color(0xFFFDE68A)
                                                  : const Color(0xFFFECACA),
                                        ),
                                      ),
                                      child: Text(
                                        'Stock: $stock $unit',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: stock > 10
                                              ? const Color(0xFF065F46)
                                              : stock > 0
                                                  ? const Color(0xFF92400E)
                                                  : const Color(0xFF991B1B),
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
                const SizedBox(height: 16),

                // Quantity & Unit Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernField(
                            controller: _qtyCtrl,
                            label: 'Quantity Needed',
                            hintText: 'Enter quantity',
                            icon: Icons.numbers_rounded,
                            isNumber: true,
                            onChanged: (val) {
                              final currentItem = _itemCtrl.text.trim();
                              if (_itemStocks.containsKey(currentItem)) {
                                final maxStock = _itemStocks[currentItem]!;
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed > maxStock) {
                                  _qtyCtrl.text = maxStock.toString();
                                  _qtyCtrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _qtyCtrl.text.length),
                                  );
                                }
                              }
                            },
                          ),
                          if (_itemStocks.containsKey(_itemCtrl.text.trim()))
                            Padding(
                              padding: const EdgeInsets.only(top: 5, left: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Available in Main Inventory: ${_itemStocks[_itemCtrl.text.trim()]} ${_itemUnits[_itemCtrl.text.trim()] ?? ''}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF047857),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: _buildModernField(
                        controller: _unitCtrl,
                        label: 'Unit of Measure',
                        hintText: 'Auto-set from item',
                        icon: Icons.straighten_rounded,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Priority Level Selector
                Text(
                  'PRIORITY LEVEL',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((p) {
                    final (key, desc, icon, color) = p;
                    final selected = _selectedPriority == key;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => setState(() => _selectedPriority = key),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? color : const Color(0xFFE2E8F0),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, color: selected ? color : const Color(0xFF94A3B8), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        key == 'Low' ? 'Standard' : 'Urgent',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: selected ? color : const Color(0xFF334155),
                                        ),
                                      ),
                                      Text(
                                        desc,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle_rounded, color: color, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Kitchen Note Field
                _buildModernField(
                  controller: _noteCtrl,
                  label: 'Kitchen Station Note (Optional)',
                  hintText: 'e.g. Needed for dinner banquet service prep, running low on line...',
                  icon: Icons.edit_note_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 22),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B211D),
                      foregroundColor: const Color(0xFFE6C374),
                      elevation: 4,
                      shadowColor: const Color(0xFF0B211D).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE6C374), width: 1.2),
                      ),
                    ),
                    child: _submitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE6C374),
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Sending Requisition to Inventory...'),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18, color: Color(0xFFE6C374)),
                              const SizedBox(width: 10),
                              Text(
                                'DISPATCH REQUEST TO INVENTORY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Modern Text Field Helper ────────────────────────────
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          readOnly: readOnly,
          onChanged: isNumber
              ? (value) {
                  final filtered = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (filtered != value) {
                    controller.value = TextEditingValue(
                      text: filtered,
                      selection: TextSelection.collapsed(offset: filtered.length),
                    );
                  }
                  if (onChanged != null) onChanged(filtered);
                }
              : onChanged,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. History Header with Status Filter Chips ──────────────
  Widget _buildHistoryHeader({
    required int total,
    required int pending,
    required int approved,
  }) {
    final filters = [
      ('All', total),
      ('Pending', pending),
      ('Approved', approved),
      ('Rejected', total - pending - approved),
    ];

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY REQUISITION FEED',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Track real-time status and stock approvals',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final (label, count) = f;
              final isSelected = _historyFilter == label;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text('$label ($count)'),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0B211D),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val) setState(() => _historyFilter = label);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Page $_currentPage of $totalPages',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  REALISTIC REQUEST HISTORY CARD
// ══════════════════════════════════════════════════════════
class _RealisticRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const _RealisticRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'Pending';
    final priority = request['priority']?.toString() ?? 'Low';
    final itemName = request['item_name']?.toString() ?? '—';
    final qty = request['quantity_needed']?.toString() ?? '0';
    final unit = request['unit']?.toString() ?? 'pcs';
    final note = request['note']?.toString() ?? '';

    final createdAt = request['created_at'] != null
        ? DateTime.tryParse(request['created_at'].toString())
        : null;
    final timeStr = createdAt != null
        ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal())
        : '—';

    // Status styling
    final isApproved = status.toLowerCase() == 'approved';
    final isRejected = status.toLowerCase() == 'rejected';
    final isPending = !isApproved && !isRejected;

    final statusBg = isApproved
        ? const Color(0xFFECFDF5)
        : isRejected
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFFFBEB);

    final statusBorder = isApproved
        ? const Color(0xFFA7F3D0)
        : isRejected
            ? const Color(0xFFFECACA)
            : const Color(0xFFFDE68A);

    final statusColor = isApproved
        ? const Color(0xFF047857)
        : isRejected
            ? const Color(0xFFB91C1C)
            : const Color(0xFFB45309);

    final statusIcon = isApproved
        ? Icons.check_circle_rounded
        : isRejected
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isPending ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFECFDF5)
                  : isPending
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: isApproved
                  ? const Color(0xFF10B981)
                  : isPending
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      itemName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (priority.toLowerCase() == 'urgent')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFDC2626)),
                            const SizedBox(width: 2),
                            Text(
                              'URGENT',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFDC2626),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B211D).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$qty $unit',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: const Color(0xFF0B211D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•   $timeStr',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Note: $note',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Status Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 920;

        Widget buildSearchField() {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1E293B), fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search kitchen inventory (e.g. Rice, Beef, Garlic)...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF0B211D),
                    size: 20,
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          );
        }

        Widget buildInventoryGrid() {
          return StreamBuilder<List<Map<String, dynamic>>>(
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
                final name = (i['name'] ?? '').toString().toLowerCase();
                final matchesSearch = _search.isEmpty || name.contains(_search);

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
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 185,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (_, i) {
                  final item = filteredItems[i];
                  final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                  final color = _getStatusColor(qty);
                  final label = _getStockStatus(qty);
                  final icon = _getStockStatusIcon(qty);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: qty == 0
                            ? const Color(0xFFFECACA)
                            : (qty <= 10 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                        width: qty <= 10 ? 1.4 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: qty == 0
                              ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['name']?.toString() ?? '—',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['category']?.toString() ?? 'General Food',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$qty ${item['unit'] ?? ''}',
                          style: GoogleFonts.plusJakartaSans(
                            color: color,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        }

        Widget buildSidebarContent(List<Map<String, dynamic>> items) {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // QUICK REQUESTS
                Text(
                  'QUICK DISPATCH REQUESTS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _bulkBtn(
                  onPressed: _requestAllItems,
                  label: 'Request All Stock',
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF0B211D),
                ),
                const SizedBox(height: 8),
                _bulkBtn(
                  onPressed: _requestAllOutOfStock,
                  label: 'Restock Out of Stock',
                  icon: Icons.error_outline_rounded,
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(height: 8),
                _bulkBtn(
                  onPressed: _requestAllLowStock,
                  label: 'Restock Low Stock',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD97706),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),

                // STOCK SUMMARY
                Text(
                  'STOCK HEALTH FILTER',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _summaryChip(
                              'OUT OF STOCK',
                              out.toString(),
                              const Color(0xFFDC2626),
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
                              const Color(0xFFD97706),
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
                              const Color(0xFF0284C7),
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
                              const Color(0xFF10B981),
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
        }

        if (isNarrow) {
          // Narrow screen: Top action & filter banner, then search and grid
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('kitchen_inventory')
                .stream(primaryKey: ['id']),
            builder: (context, snap) {
              final items = snap.data ?? [];
              int out = 0, low = 0;
              for (final i in items) {
                final qty = (i['quantity'] as num?)?.toInt() ?? 0;
                if (qty == 0) out++;
                else if (qty <= 10) low++;
              }

              return Column(
                children: [
                  // Mobile Quick Action Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                            label: Text('Out ($out)'),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _selectedFilter == 'OUT OF STOCK' ? Colors.white : const Color(0xFFDC2626),
                            ),
                            backgroundColor: _selectedFilter == 'OUT OF STOCK' ? const Color(0xFFDC2626) : const Color(0xFFFEE2E2),
                            onPressed: () => setState(() {
                              _selectedFilter = _selectedFilter == 'OUT OF STOCK' ? null : 'OUT OF STOCK';
                            }),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                            label: Text('Low ($low)'),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _selectedFilter == 'LOW STOCK' ? Colors.white : const Color(0xFFD97706),
                            ),
                            backgroundColor: _selectedFilter == 'LOW STOCK' ? const Color(0xFFD97706) : const Color(0xFFFEF3C7),
                            onPressed: () => setState(() {
                              _selectedFilter = _selectedFilter == 'LOW STOCK' ? null : 'LOW STOCK';
                            }),
                          ),
                          const SizedBox(width: 6),
                          if (_selectedFilter != null) ...[
                            ActionChip(
                              avatar: const Icon(Icons.clear_rounded, size: 14),
                              label: const Text('Clear Filter'),
                              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                              onPressed: () => setState(() => _selectedFilter = null),
                            ),
                            const SizedBox(width: 6),
                          ],
                          ElevatedButton.icon(
                            onPressed: _submitting ? null : _requestAllOutOfStock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B211D),
                              foregroundColor: const Color(0xFFE6C374),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 13),
                            label: Text('Restock Out', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  buildSearchField(),
                  Expanded(child: buildInventoryGrid()),
                ],
              );
            },
          );
        }

        // Desktop layout: Side-by-side with 72% / 28% split
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  buildSearchField(),
                  Expanded(child: buildInventoryGrid()),
                ],
              ),
            ),
            Container(
              width: 290,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('kitchen_inventory')
                    .stream(primaryKey: ['id']),
                builder: (context, snap) {
                  return buildSidebarContent(snap.data ?? []);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bulkBtn({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    Color color = AppTheme.primaryColor,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : onPressed,
        icon: _submitting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 16, color: color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: color.withValues(alpha: 0.28), width: 1.2),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.35),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.95)
                      : color.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
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

/// Strips out internal check-in logs like "[Checked In at ...]" from customer special requests
/// so chefs only see actual customer cooking/prep notes.
String _cleanSpecialRequests(dynamic raw) {
  if (raw == null) return '';
  final str = raw.toString();
  final cleaned = str.replaceAll(RegExp(r'\[Checked In at [^\]]+\]', caseSensitive: false), '').trim();
  return cleaned;
}

/// Returns the order ID exactly as shown on the printed receipt — always matches.
String _formatOrderId(Map<String, dynamic> order) {
  final txn = order['transaction_id']?.toString();
  if (txn != null && txn.isNotEmpty) return '#$txn';
  // Fallback for very old orders without a transaction_id
  final id = order['id']?.toString() ?? '???';
  final asInt = int.tryParse(id);
  return '#${asInt != null ? asInt.toString().padLeft(3, '0') : id.substring(id.length > 6 ? id.length - 6 : 0).toUpperCase()}';
}

/// Formats an order scheduled time to a friendly 12-hour AM/PM string (e.g. "15:00:00" → "3:00 PM").
String _formatFriendlyTime(String? orderTime) {
  if (orderTime == null || orderTime.isEmpty) return '—';
  try {
    DateTime? parsed;
    final formats = ['h:mm a', 'h:mm:ss a', 'HH:mm', 'HH:mm:ss', 'h:mm'];
    for (final fmt in formats) {
      try {
        parsed = DateFormat(fmt).parse(orderTime);
        break;
      } catch (_) {}
    }
    if (parsed == null) return orderTime;
    return DateFormat('h:mm a').format(parsed);
  } catch (_) {
    return orderTime;
  }
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
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF133831).withValues(alpha: 0.07),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF133831).withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF133831).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 44, color: const Color(0xFF133831)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Animated Top Toast Notification Banner for Chef
class _ChefTopToastWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Duration? duration;

  const _ChefTopToastWidget({
    required this.child,
    required this.onDismiss,
    this.duration,
  });

  @override
  State<_ChefTopToastWidget> createState() => _ChefTopToastWidgetState();
}

class _ChefTopToastWidgetState extends State<_ChefTopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding > 0 ? topPadding + 10 : 18,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
