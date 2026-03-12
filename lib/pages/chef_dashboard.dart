import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

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
    _orderStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) {
      if (!mounted) return;

      // Count orders whose kitchen status is Pending (not yet tracked = Pending)
      _refreshPendingCount(rows);
    });
  }

  Future<void> _refreshPendingCount(
      List<Map<String, dynamic>> orders) async {
    try {
      int pending = 0;
      for (final o in orders) {
        final ks = o['kitchen_status']?.toString() ?? 'Pending';
        if (ks == 'Pending') pending++;
      }

      if (!mounted) return;
      final isNew = pending > _lastSeenPendingCount;
      setState(() => _pendingOrderCount = pending);

      if (isNew && _currentTab != 0) {
        _lastSeenPendingCount = pending;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('$pending new order${pending == 1 ? '' : 's'} in the kitchen!'),
              ],
            ),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        _lastSeenPendingCount = pending;
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
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          // System Logo
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'KITCHEN',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Yang Chow System',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // clock
          StreamBuilder<DateTime>(
            stream: Stream.periodic(
                const Duration(seconds: 1), (_) => DateTime.now()),
            builder: (context, snap) {
              final now = snap.data ?? DateTime.now();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('h:mm:ss a').format(now),
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      DateFormat('EEE, MMM d').format(now).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: Color(0xFF64748B), size: 20),
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
      (Icons.check_circle_outline, 'Finished'),
      (Icons.inventory_2_outlined, 'Requests'),
      (Icons.bar_chart, 'Stock'),
    ];

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _currentTab == i;
          final (icon, label) = items[i];
          final hasBadge = i == 0 && _pendingOrderCount > 0;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
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
                        Icon(icon,
                            color: selected ? AppTheme.primaryRed : const Color(0xFF64748B),
                            size: 24),
                        if (hasBadge)
                          Positioned(
                            top: -2,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryRed,
                                  shape: BoxShape.circle),
                              child: Text(
                                '$_pendingOrderCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? AppTheme.primaryRed : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
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
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
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
  // Kitchen status for each order (order_id → status)
  final Map<String, String> _kitchenStatus = {};

  static const _statusOrder = ['Pending', 'Preparing', 'Ready', 'Done'];
  static const _statusColors = {
    'Pending': Color(0xFFFFA726),
    'Preparing': Color(0xFF2196F3),
    'Ready': Color(0xFF4CAF50),
    'Done': Color(0xFF9E9E9E),
  };

  @override
  void initState() {
    super.initState();
    // No separate table to load; kitchen_status is a column on orders
  }

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
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed));
        }
        final rawOrders = snap.data ?? [];

        // Sync local cache from DB column (kitchen_status on orders)
        for (final o in rawOrders) {
          final id = o['id'].toString();
          if (!_kitchenStatus.containsKey(id)) {
            _kitchenStatus[id] = o['kitchen_status']?.toString() ?? 'Pending';
          }
        }

        final orders = rawOrders.where((o) {
          final ks = _kitchenStatus[o['id'].toString()] ?? 'Pending';
          return ks != 'Done' && ks != 'Ready';
        }).toList();

        if (orders.isEmpty) {
          return _buildEmptyState(
            Icons.check_circle_outline,
            'All clear!',
            'No active orders in the kitchen.',
          );
        }

        // Group by kitchen status (only Pending and Preparing remain in kitchen)
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final s in ['Pending', 'Preparing']) {
          grouped[s] = orders
              .where((o) =>
                  (_kitchenStatus[o['id'].toString()] ?? 'Pending') == s)
              .toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            if (isWide) {
              // Two-column grid for tablets/wide screens
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 1000 ? 5 : (constraints.maxWidth > 750 ? 4 : (constraints.maxWidth > 500 ? 3 : 2)),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: constraints.maxWidth > 750 ? 0.75 : 0.85,
                ),
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final o = orders[i];
                  return _KitchenOrderCard(
                    order: o,
                    kitchenStatus:
                        _kitchenStatus[o['id'].toString()] ?? 'Pending',
                    onStatusChanged: (ns) =>
                        _updateStatus(o['id'].toString(), ns),
                    statusOrder: _statusOrder,
                    statusColors: _statusColors,
                  );
                },
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final status in ['Pending', 'Preparing']) ...[
                  if ((grouped[status] ?? []).isNotEmpty) ...[
                    _buildStatusHeader(status),
                    ...grouped[status]!
                        .map((o) => _KitchenOrderCard(
                              order: o,
                              kitchenStatus:
                                  _kitchenStatus[o['id'].toString()] ?? 'Pending',
                              onStatusChanged: (ns) =>
                                  _updateStatus(o['id'].toString(), ns),
                              statusOrder: _statusOrder,
                              statusColors: _statusColors,
                            )),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusHeader(String status) {
    final color = _statusColors[status] ?? AppTheme.mediumGrey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
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

  const _KitchenOrderCard({
    required this.order,
    required this.kitchenStatus,
    required this.onStatusChanged,
    required this.statusOrder,
    required this.statusColors,
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
    try {
      final rows = await Supabase.instance.client
          .from('order_items')
          .select('item_name, quantity, unit_price')
          .eq('order_id', widget.order['id'].toString());
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
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

    final isUrgent = elapsed != null && elapsed.inMinutes >= 15 && status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.red.shade400 : color.withValues(alpha: 0.5),
          width: isUrgent ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              color: color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Order badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Row(
                        children: [
                          Text(timeStr,
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 12)),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Text('•',
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11),
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
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 12),
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
                            fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Items List ────────────────────────────────
          // ── Items List (Scrollable & Expanded) ────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_items.isEmpty)
                    const Text('Loading items…',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 12))
                  else
                    ..._items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '×${item['quantity']}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10),
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
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )),

                  // note field
                  if ((widget.order['note']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.note_alt_outlined,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.order['note'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.amber, fontSize: 11),
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
                        onPressed: () =>
                            widget.onStatusChanged(nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nextStatus == 'Done'
                              ? AppTheme.successGreen
                              : widget.statusColors[nextStatus] ??
                                  AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        icon: Icon(_nextStatusIcon(nextStatus), size: 16),
                        label: Text(nextStatus == 'Done'
                            ? '✓ READY'
                            : nextStatus.toUpperCase()),
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
                          widget.statusOrder[currentIdx - 1]),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFFF1F5F9)),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
class _FinishedOrdersTab extends StatelessWidget {
  const _FinishedOrdersTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDoneOrders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed));
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return _buildEmptyState(
              Icons.hourglass_empty, 'No finished orders yet', '');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (_, i) => _FinishedOrderCard(order: orders[i]),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDoneOrders() async {
    try {
      final orders = await Supabase.instance.client
          .from('orders')
          .select()
          .inFilter('kitchen_status', ['Ready', 'Done'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(orders);
    } catch (_) {
      return [];
    }
  }
}

class _FinishedOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _FinishedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final customer = order['customer_name']?.toString() ?? 'Guest';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())
        : null;
    final timeStr = createdAt != null
        ? DateFormat('MMM d, hh:mm a').format(createdAt.toLocal())
        : '—';
    final orderId = _formatOrderId(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.successGreen.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    orderId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer,
                          style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${NumberFormat('#,##0.00').format(total)}',
                      style: const TextStyle(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text('SERVED',
                        style: TextStyle(
                            color: AppTheme.successGreen.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
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
  String _selectedUnit = 'pcs';
  String _selectedPriority = 'Normal';
  bool _submitting = false;

  static const _units = ['pcs', 'kilo', 'gram', 'pack', 'bot', 'can', 'box', 'order'];
  static const _priorities = ['Low', 'Normal', 'High', 'Urgent'];

  static const _priorityColors = {
    'Low': Color(0xFF4CAF50),
    'Normal': Color(0xFF2196F3),
    'High': Color(0xFFFFA726),
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

  void _onItemChanged() {
    final itemName = _itemCtrl.text.trim();
    
    // Auto-update unit if exact match found
    if (_itemUnits.containsKey(itemName)) {
      setState(() {
        _selectedUnit = _itemUnits[itemName]!;
      });
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
              item['name'].toString(): item['unit']?.toString() ?? 'pcs'
          };
          _itemStocks = {
            for (var item in items)
              item['name'].toString(): (item['quantity'] as num?)?.toInt() ?? 0
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
          content: Text('"$itemName" is not available in inventory. Please select from available items.'),
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
          content: Text('Cannot request $qty $itemName. Only $availableStock ${_itemUnits[itemName] ?? 'pcs'} available in inventory.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final chef =
          Supabase.instance.client.auth.currentUser?.email ?? 'chef';
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
          _selectedUnit = 'pcs';
          _selectedPriority = 'Normal';
          _submitting = false;
        });
        
        // Show success dialog with redirect option
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen, size: 24),
                SizedBox(width: 12),
                Text('Request Submitted!', style: TextStyle(color: AppTheme.darkGrey)),
              ],
            ),
            content: const Text(
              'Your stock request has been sent to the inventory team. You can track its status in the Pagsanjaninv dashboard.',
              style: TextStyle(color: AppTheme.darkGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppTheme.mediumGrey)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
                const Row(
                  children: [
                    Icon(Icons.add_shopping_cart,
                        color: AppTheme.primaryRed, size: 22),
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
                const SizedBox(height: 16),

                // Item name with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lightField(_itemCtrl, 'Item Name', Icons.inventory_2_outlined),
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
                            final unit = _itemUnits[suggestion] ?? 'pcs';
                            final stock = _itemStocks[suggestion] ?? 0;
                            return InkWell(
                              onTap: () => _selectSuggestion(suggestion),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                              color: stock == 0 ? AppTheme.errorRed : 
                                                     stock < 10 ? AppTheme.warningOrange : AppTheme.successGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        unit,
                                        style: TextStyle(
                                          color: AppTheme.primaryRed,
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
                  children: [
                    Expanded(
                      child: _lightField(_qtyCtrl, 'Quantity', Icons.numbers,
                          isNumber: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _lightDropdown<String>(
                        value: _selectedUnit,
                        items: _units,
                        label: 'Unit',
                        icon: Icons.straighten,
                        onChanged: (v) =>
                            setState(() => _selectedUnit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Priority
                const Text('Priority',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((p) {
                    final selected = _selectedPriority == p;
                    final color =
                        _priorityColors[p] ?? AppTheme.infoBlue;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedPriority = p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
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
                                color:
                                    selected ? color : const Color(0xFF64748B),
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
                _lightField(_noteCtrl, 'Note (optional)', Icons.note_alt_outlined,
                    maxLines: 2),
                const SizedBox(height: 18),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_submitting
                        ? 'Submitting…'
                        : 'Send Request to Inventory'),
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
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryRed),
                ));
              }
              final requests = snap.data!;
              if (requests.isEmpty) {
                return _buildEmptyState(Icons.inbox_outlined,
                    'No requests yet', 'Submit a request above.');
              }
              return Column(
                children: requests
                    .map((r) => _RequestHistoryCard(
                          request: r,
                          statusColors: _statusColors,
                          priorityColors: _priorityColors,
                        ))
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
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primaryRed, size: 18),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _lightDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.primaryRed, size: 18),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem<T>(
              value: i,
              child: Text(i.toString(),
                  style: const TextStyle(color: Color(0xFF1E293B)))))
          .toList(),
      onChanged: onChanged,
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
                          fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(priority,
                          style: TextStyle(
                              color: priorityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${request['quantity_needed']} ${request['unit']}  •  $timeStr',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 12),
                ),
                if ((request['note']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      request['note'].toString(),
                      style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
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

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'OUT OF STOCK';
    if (quantity < 10) return 'LOW STOCK';
    if (quantity < 50) return 'NORMAL';
    return 'HIGH STOCK';
  }

  Color _getStatusColor(int quantity) {
    if (quantity == 0) return AppTheme.errorRed;
    if (quantity < 10) return AppTheme.warningOrange;
    if (quantity < 50) return AppTheme.infoBlue;
    return AppTheme.successGreen;
  }

  IconData _getStockStatusIcon(int quantity) {
    if (quantity == 0) return Icons.remove_circle;
    if (quantity < 10) return Icons.warning_amber_rounded;
    if (quantity < 50) return Icons.inventory_2_rounded;
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search ingredients…',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryRed, size: 20),
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
                borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
              ),
            ),
          ),
        ),

        // Stock summary chips
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('inventory')
              .stream(primaryKey: ['id']),
          builder: (context, snap) {
            final items = snap.data ?? [];
            int out = 0, low = 0, ok = 0, high = 0;
            for (final i in items) {
              final qty = (i['quantity'] as num?)?.toInt() ?? 0;
              if (qty == 0) { out++; }
              else if (qty < 10) { low++; }
              else if (qty < 50) { ok++; }
              else { high++; }
            }

            if (out > 0 && snap.hasData) {
              // Show alert banner for out-of-stock
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Notification is handled inline below
              });
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _summaryChip('OUT OF STOCK', out.toString(),
                      AppTheme.errorRed,
                      isSelected: _selectedFilter == 'OUT OF STOCK',
                      onTap: () => setState(() {
                        _selectedFilter = _selectedFilter == 'OUT OF STOCK' ? null : 'OUT OF STOCK';
                      })),
                  const SizedBox(width: 8),
                  _summaryChip('LOW STOCK', low.toString(),
                      AppTheme.warningOrange,
                      isSelected: _selectedFilter == 'LOW STOCK',
                      onTap: () => setState(() {
                        _selectedFilter = _selectedFilter == 'LOW STOCK' ? null : 'LOW STOCK';
                      })),
                  const SizedBox(width: 8),
                  _summaryChip('NORMAL', ok.toString(),
                      AppTheme.infoBlue,
                      isSelected: _selectedFilter == 'NORMAL',
                      onTap: () => setState(() {
                        _selectedFilter = _selectedFilter == 'NORMAL' ? null : 'NORMAL';
                      })),
                  const SizedBox(width: 8),
                  _summaryChip('HIGH STOCK', high.toString(),
                      AppTheme.successGreen,
                      isSelected: _selectedFilter == 'HIGH STOCK',
                      onTap: () => setState(() {
                        _selectedFilter = _selectedFilter == 'HIGH STOCK' ? null : 'HIGH STOCK';
                      })),
                ],
              ),
            );
          },
        ),

        // Grid
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('inventory')
                .stream(primaryKey: ['id'])
                .order('quantity', ascending: true),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryRed));
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
                final matchesStatus = _selectedFilter == null || status == _selectedFilter;
                
                return matchesSearch && matchesStatus;
              }).toList();
              
              if (!hasItems) {
                return _buildEmptyState(Icons.inventory_2_outlined,
                    'No items in inventory', 'Add items in Pagsanjaninv dashboard first');
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
                return _buildEmptyState(Icons.inventory_2_outlined, message, subtitle);
              }
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 600 ? 6 : constraints.maxWidth > 400 ? 3 : 2;
                  return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (_, i) {
                  final item = filteredItems[i];
                  final qty =
                      (item['quantity'] as num?)?.toInt() ?? 0;
                  final color = _getStatusColor(qty);
                  final label = _getStockStatus(qty);
                  final icon = _getStockStatusIcon(qty);
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB)),
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
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String count, Color color, {bool isSelected = false, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(count,
                  style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : color.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
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
        Text(title,
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ],
      ],
    ),
  );
}
