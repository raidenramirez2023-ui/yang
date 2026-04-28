import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
      for (final o in orders) {
        final ks = o[isAdvance ? 'status' : 'kitchen_status']?.toString() ?? 'Pending';
        final ps = o['payment_status']?.toString() ?? 'unpaid';
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

      if (isNew && _currentTab != (isAdvance ? 1 : 0)) {
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
                  _KitchenOrdersTab(),
                  _AdvanceOrdersTab(),
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
  Widget _buildHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          // System Logo
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'KITCHEN',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // clock
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
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(now).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('h:mm:ss a').format(now),
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // logout
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _confirmLogout,
            child: Container(
               padding: const EdgeInsets.all(6),
               decoration: BoxDecoration(
                 color: const Color(0xFFF1F5F9),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: const Icon(
                 Icons.logout,
                 color: Color(0xFF64748B),
                 size: 18,
               ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation ────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (Icons.restaurant, 'Kitchen'),
      (Icons.event_note, 'Advance'),
      (Icons.check_circle_outline, 'Finished'),
      (Icons.inventory_2_outlined, 'Requests'),
      (Icons.fact_check, 'Stock'),
    ];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _currentTab == i;
          final (icon, label) = items[i];
          final hasBadge = (i == 0 && _pendingRegular > 0) || (i == 1 && _pendingAdvance > 0);
          final badgeCount = i == 0 ? _pendingRegular : _pendingAdvance;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
                setState(() => _currentTab = i);
              },
              child: Container(
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icon,
                          color: selected
                              ? AppTheme.primaryColor
                              : const Color(0xFF64748B),
                          size: 18,
                        ),
                        if (hasBadge)
                          Positioned(
                            top: -2,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : const Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
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
//  TAB 1 — KITCHEN ORDERS
// ══════════════════════════════════════════════════════════
class _KitchenOrdersTab extends StatefulWidget {
  const _KitchenOrdersTab();

  @override
  State<_KitchenOrdersTab> createState() => _KitchenOrdersTabState();
}

class _KitchenOrdersTabState extends State<_KitchenOrdersTab> {
  final Map<String, String> _kitchenStatus = {};

  static const _statusOrder = ['Pending', 'Preparing', 'Ready', 'Done'];
  static const _statusColors = {
    'Pending': Color(0xFFFFA726),
    'Preparing': Color(0xFF2196F3),
    'Ready': Color(0xFF4CAF50),
    'Done': Color(0xFF9E9E9E),
  };

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _kitchenStatus[orderId] = newStatus);
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final ordersRaw = snapshot.data ?? [];
        
        // Sync local cache
        for (final o in ordersRaw) {
          final id = o['id'].toString();
          if (!_kitchenStatus.containsKey(id)) {
            _kitchenStatus[id] = o['kitchen_status']?.toString() ?? 'Pending';
          }
        }

        final orders = ordersRaw.where((o) {
          final ks = _kitchenStatus[o['id'].toString()] ?? 'Pending';
          final ps = o['payment_status']?.toString() ?? 'unpaid';
          return ks != 'Done' && ks != 'Ready' && (ps == 'paid' || ps == 'fully_paid');
        }).toList();

        if (orders.isEmpty) {
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
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                final id = o['id'].toString();
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 330,
                    height: 330 / 1.05,
                    child: _KitchenOrderCard(
                      order: o,
                      kitchenStatus: _kitchenStatus[id] ?? 'Pending',
                      onStatusChanged: (ns) => _updateStatus(id, ns),
                      statusOrder: _statusOrder,
                      statusColors: _statusColors,
                      isAdvanceOrder: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdvanceOrdersTab extends StatefulWidget {
  const _AdvanceOrdersTab();

  @override
  State<_AdvanceOrdersTab> createState() => _AdvanceOrdersTabState();
}

class _AdvanceOrdersTabState extends State<_AdvanceOrdersTab> {
  final Map<String, String> _kitchenStatus = {};

  static const _statusOrder = ['Pending', 'Preparing', 'Ready', 'Done'];
  static const _statusColors = {
    'Pending': Color(0xFFFFA726),
    'Preparing': Color(0xFF2196F3),
    'Ready': Color(0xFF4CAF50),
    'Done': Color(0xFF9E9E9E),
  };

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _kitchenStatus[orderId] = newStatus);
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



  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('advance_orders')
          .stream(primaryKey: ['id'])
          .order('order_date', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final raw = snapshot.data ?? [];
        final orders = raw.map((o) {
          final status = o['status']?.toString().toLowerCase();
          return {
            ...o,
            '_is_advance': true,
            'kitchen_status': status == 'preparing' ? 'Preparing' :
                             status == 'ready' ? 'Ready' :
                             status == 'done' ? 'Done' : 'Pending',
          };
        }).where((o) {
          final ks = o['kitchen_status'];
          final ps = o['payment_status']?.toString().toLowerCase();
          return ks != 'Done' && ks != 'Ready' && (ps == 'paid' || ps == 'fully_paid');
        }).toList();

        if (orders.isEmpty) {
          return _buildEmptyState(Icons.event_note, 'No Advance Orders', 'Future orders will appear here.');
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
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                final id = o['id'].toString();
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 330,
                    height: 330 / 1.05,
                    child: _KitchenOrderCard(
                      order: o,
                      kitchenStatus: o['kitchen_status'] ?? 'Pending',
                      onStatusChanged: (ns) => _updateStatus(id, ns),
                      statusOrder: _statusOrder,
                      statusColors: _statusColors,
                      isAdvanceOrder: true,
                    ),
                  ),
                );
              },
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

  const _KitchenOrderCard({
    required this.order,
    required this.kitchenStatus,
    required this.onStatusChanged,
    required this.statusOrder,
    required this.statusColors,
    required this.isAdvanceOrder,
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
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (widget.isAdvanceOrder) {
      // For advance orders, items are in selected_menu_items JSON column
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

  @override
  Widget build(BuildContext context) {
    final status = widget.kitchenStatus;
    final color = widget.statusColors[status] ?? AppTheme.mediumGrey;
    final customer = widget.order['customer_name']?.toString() ?? 'Guest';
    final createdAt = widget.order['created_at'] != null
        ? DateTime.tryParse(widget.order['created_at'].toString())
        : null;
    final timeStr = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '—';
    final elapsed = createdAt != null
        ? DateTime.now().difference(createdAt.toLocal())
        : null;
    final elapsedStr = elapsed != null
        ? elapsed.inMinutes < 1
              ? 'Just now'
              : '${elapsed.inMinutes} min ago'
        : '';

    final currentIdx = widget.statusOrder.indexOf(status);
    final nextStatus = currentIdx < widget.statusOrder.length - 1
        ? widget.statusOrder[currentIdx + 1]
        : null;

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
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.statusColors[widget.kitchenStatus]?.withOpacity(0.08) ?? Colors.grey.shade100,
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
                                widget.isAdvanceOrder ? 'ADVANCE ORDER' : 'Order ${_formatOrderId(widget.order)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: widget.isAdvanceOrder ? AppTheme.primaryColor : const Color(0xFF1E293B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (widget.isAdvanceOrder)
                                Text(
                                  'Scheduled: ${widget.order['order_date']} at ${widget.order['order_time']}',
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
                  if (widget.isAdvanceOrder && widget.order['preparation_notes'] != null && widget.order['preparation_notes'].toString().isNotEmpty)
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

    return GestureDetector(
      onTap: () => showOrderDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.red.shade400 : color.withOpacity(0.5),
          width: isUrgent ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ───────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Order badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatOrderId(widget.order),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (widget.isAdvanceOrder && 
                    (widget.order['payment_status'] == 'paid' || 
                     widget.order['payment_status'] == 'fully_paid')) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                          if (widget.order['table_number']
                                  ?.toString()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.isAdvanceOrder 
                                  ? '${widget.order['order_type']}'
                                  : 'Table ${widget.order['table_number']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (widget.order['number_of_guests'] != null) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${widget.order['number_of_guests']} ${widget.order['number_of_guests'] == 1 ? 'guest' : 'guests'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isUrgent)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                const SizedBox(width: 4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          elapsedStr,
                          style: TextStyle(
                            color: isUrgent
                                ? Colors.red.shade400
                                : const Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: isUrgent
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: color.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
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

          // ── Items List (Scrollable & Expanded) ────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_items.isEmpty)
                    const Text(
                      'Loading items…',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    )
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '×${item['quantity']}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['item_name']?.toString() ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // note field
                  if ((widget.order['note']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.note_alt_outlined,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.order['note'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
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

          // ── Action Buttons (Anchored to Bottom) ───────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (nextStatus != null)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onStatusChanged(nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nextStatus == 'Done'
                              ? AppTheme.successGreen
                              : widget.statusColors[nextStatus] ??
                                    AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        icon: Icon(_nextStatusIcon(nextStatus), size: 16),
                        label: Text(
                          nextStatus == 'Done'
                              ? '✓ READY'
                              : nextStatus.toUpperCase(),
                        ),
                      ),
                    ),
                  ),
                if (currentIdx > 0) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 40,
                    width: 44,
                    child: OutlinedButton(
                      onPressed: () => widget.onStatusChanged(
                        widget.statusOrder[currentIdx - 1],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFFF1F5F9)),
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
        return Icons.local_fire_department;
      case 'Ready':
        return Icons.restaurant;
      case 'Done':
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 2 — FINISHED ORDERS
// ══════════════════════════════════════════════════════════
class _FinishedOrdersTab extends StatefulWidget {
  const _FinishedOrdersTab();

  @override
  State<_FinishedOrdersTab> createState() => _FinishedOrdersTabState();
}

class _FinishedOrdersTabState extends State<_FinishedOrdersTab> {
  int _currentPage = 1;
  static const int _itemsPerPage = 50;
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchDoneOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchDoneOrders() async {
    try {
      final orders = await Supabase.instance.client
          .from('orders')
          .select()
          .inFilter('kitchen_status', ['Ready', 'Done'])
          .order('created_at', ascending: false);

      final advanceOrdersRaw = await Supabase.instance.client
          .from('advance_orders')
          .select()
          .inFilter('status', ['ready', 'done'])
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> advanceOrders = advanceOrdersRaw.map((o) {
        return {
          ...o,
          '_is_advance': true,
          'kitchen_status': o['status']?.toString().toLowerCase() == 'ready' ? 'Ready' : 'Done',
        };
      }).toList();

      final List<Map<String, dynamic>> combined = [
        ...List<Map<String, dynamic>>.from(orders),
        ...advanceOrders
      ];
      
      // Sort by creation time
      combined.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      return combined;
    } catch (_) {
      return [];
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
        if (allOrders.isEmpty) {
          return _buildEmptyState(
            Icons.hourglass_empty,
            'No finished orders yet',
            '',
          );
        }

        final int totalPages = (allOrders.length / _itemsPerPage).ceil();
        if (_currentPage > totalPages && totalPages > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentPage = totalPages);
          });
        }

        final int startIndex = (_currentPage - 1) * _itemsPerPage;
        int endIndex = startIndex + _itemsPerPage;
        if (endIndex > allOrders.length) endIndex = allOrders.length;

        final currentOrders = (startIndex < allOrders.length)
            ? allOrders.sublist(startIndex, endIndex)
            : <Map<String, dynamic>>[];

        return Column(
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Order ID',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Amount',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: currentOrders.length,
                itemBuilder: (_, i) => _FinishedOrderCard(order: currentOrders[i]),
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
                    color: AppTheme.primaryColor.withOpacity(0.3),
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
              color: Colors.black.withOpacity(0.1),
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
    final orderId = isAdvance 
        ? 'ADV-${order['id'].toString().substring(0, 4)}' 
        : _formatOrderId(order);
    final customer = order['customer_name']?.toString() ?? 'Guest';
    final total = (order['total_price'] ?? order['total_amount'] ?? 0.0).toDouble();
    
    final createdAt = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())
        : null;
    final timeStr = isAdvance 
        ? '${order['order_date']} ${order['order_time']}'
        : (createdAt != null ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal()) : '—');
    
    final tableNumber = order['table_number']?.toString();
    final orderType = order['order_type']?.toString();
    final numberOfGuests = order['number_of_guests'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF1F5F9), // Lighter border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Order ID column
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  orderId,
                  style: TextStyle(
                    color: isAdvance ? AppTheme.primaryColor : AppTheme.successGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // Details column
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      customer.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isAdvance ? AppTheme.primaryColor.withOpacity(0.6) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (numberOfGuests != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$numberOfGuests',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (isAdvance && orderType != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        orderType == 'Pickup' ? Icons.shopping_bag_outlined : Icons.restaurant,
                        size: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orderType.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (!isAdvance && tableNumber != null && tableNumber.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.table_restaurant,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'T-$tableNumber',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Amount column
          Expanded(
            flex: 2,
            child: Text(
              '₱${NumberFormat('#,##0.00').format(total)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Status column
          Expanded(
             flex: 2,
             child: Align(
               alignment: Alignment.centerRight,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: AppTheme.successGreen,
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: const [
                     Icon(
                       Icons.check,
                       color: Colors.white,
                       size: 14,
                     ),
                     SizedBox(width: 4),
                     Text(
                       'SERVED',
                       style: TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.w700,
                         fontSize: 11,
                         letterSpacing: 0.5,
                       ),
                     ),
                   ],
                 ),
               ),
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
        'created_at': DateTime.now().toIso8601String(),
      });

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
                  color: Colors.black.withOpacity(0.04),
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
                              color: Colors.black.withOpacity(0.1),
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
                                      ).withOpacity(0.5),
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
                                  ? color.withOpacity(0.1)
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
              return Column(
                children: requests
                    .map(
                      (r) => _RequestHistoryCard(
                        request: r,
                        statusColors: _statusColors,
                        priorityColors: _priorityColors,
                      ),
                    )
                    .toList(),
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
            color: Colors.black.withOpacity(0.02),
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
                        color: priorityColor.withOpacity(0.1),
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
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.5)),
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
        filter: (name, mainQty, kitchenQty) => mainQty > 0,
        note: 'Bulk request (Restock all)',
      );

  Future<void> _requestAllOutOfStock() => _runBulkRequest(
        title: 'Only out-of-stock items',
        filter: (name, mainQty, kitchenQty) => kitchenQty <= 0,
        note: 'Bulk request (Kitchen is OUT)',
      );

  Future<void> _requestAllLowStock() => _runBulkRequest(
        title: 'Only low-stock items',
        filter: (name, mainQty, kitchenQty) =>
            kitchenQty >= 1 && kitchenQty <= 10,
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
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await Supabase.instance.client.from('kitchen_requests').insert(requests);

      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully requested ${requests.length} items!'),
            backgroundColor: AppTheme.successGreen,
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
                                    color: Colors.black.withOpacity(0.02),
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
                                      color: color.withOpacity(0.2),
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
                              label: 'Request ALL',
                              icon: Icons.auto_awesome,
                            ),
                            const SizedBox(height: 10),
                            _bulkBtn(
                              onPressed: _requestAllOutOfStock,
                              label: 'OUT of Stock',
                              icon: Icons.remove_circle_outline,
                              color: AppTheme.errorRed,
                            ),
                            const SizedBox(height: 10),
                            _bulkBtn(
                              onPressed: _requestAllLowStock,
                              label: 'LOW Stock',
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
          backgroundColor: color.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: color.withOpacity(0.2), width: 1),
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
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
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
                      ? Colors.white.withOpacity(0.9)
                      : color.withOpacity(0.8),
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

Widget _buildEmptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ],
    ),
  );
}
