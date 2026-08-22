import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/staff/inventory_management.dart';
import 'package:yang_chow/pages/staff/inventory_room_page.dart';
import 'package:yang_chow/pages/staff/petty_cash_expense_page.dart';
import 'package:yang_chow/pages/staff/spoilage_wastage_page.dart';
import 'package:yang_chow/widgets/purchase_order_generator_dialog.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class PagsanjaninvDashboardPage extends StatefulWidget {
  const PagsanjaninvDashboardPage({super.key});

  @override
  State<PagsanjaninvDashboardPage> createState() => _PagsanjaninvDashboardPageState();
}

class _PagsanjaninvDashboardPageState extends State<PagsanjaninvDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _userName = 'Admin';
  int _totalInventoryItems = 0;
  int _lowStockItems = 0;
  int _outOfStockItems = 0;
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _currentPage = 1;
  final int _itemsPerPage = 15;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedWeek = 1;
  int _requestFilter = 0; // 0: All, 1: Pending, 2: Approved, 3: Rejected
  final List<String> _requestFilterLabels = ['All', 'Pending', 'Approved', 'Rejected'];

  List<Map<String, dynamic>> _topRequestedItems = [];
  Map<String, Map<String, int>> _inventoryHealthByCategory = {};
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _criticalItems = [];
  Set<String> _previouslyAlertedCriticalIds = {};
  bool _isLineChartForRequests = false;
  bool _isLineChartForHealth = false;

  RealtimeChannel? _inventorySubscription;
  late Stream<List<Map<String, dynamic>>> _allRequestsStream;

  int _getCurrentWeekOfMonth(DateTime date) {
    int day = date.day;
    if (day <= 7) return 1;
    if (day <= 14) return 2;
    if (day <= 21) return 3;
    return 4;
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return dateTimeStr;
    }
  }

  // ── Top Toast Notification Overlay for Inventory ──
  OverlayEntry? _currentInvTopToastEntry;
  Timer? _invTopToastTimer;
  final Set<String> _shownToastInvNotificationIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _invNotifsSubscription;

  void _dismissInvTopToast() {
    _invTopToastTimer?.cancel();
    _invTopToastTimer = null;
    _currentInvTopToastEntry?.remove();
    _currentInvTopToastEntry = null;
  }

  void _showInvTopToast({
    required Widget content,
    Duration? duration,
  }) {
    if (!mounted) return;
    _dismissInvTopToast();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InvTopToastWidget(
        onDismiss: () {
          if (_currentInvTopToastEntry == entry) {
            _dismissInvTopToast();
          }
        },
        duration: duration,
        child: content,
      ),
    );

    _currentInvTopToastEntry = entry;
    overlay.insert(entry);

    if (duration != null) {
      _invTopToastTimer = Timer(duration, () {
        if (_currentInvTopToastEntry == entry) {
          _dismissInvTopToast();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _allRequestsStream = _supabase
        .from('kitchen_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedWeek = _getCurrentWeekOfMonth(now);
    _loadDashboardData();
    _setupRealtimeSubscription();

    _invNotifsSubscription = NotificationService.getInventoryNotificationsStream().listen((notifs) {
      if (!mounted) return;
      final unread = notifs.where((n) => n['is_read'] == false).toList();
      if (unread.isNotEmpty) {
        final latest = unread.first;
        final id = latest['id']?.toString();
        if (id != null && !_shownToastInvNotificationIds.contains(id)) {
          _shownToastInvNotificationIds.add(id);
          _showInvNotificationToast(latest);
        }
      }
    });
  }

  void _setupRealtimeSubscription() {
    _inventorySubscription = _supabase
        .channel('public:inventory_dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kitchen_requests',
          callback: (payload) {
            if (mounted) _loadDashboardData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _invNotifsSubscription?.cancel();
    _dismissInvTopToast();
    _inventorySubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.email?.split('@')[0] ?? 'Admin';
        });
      }

      final inventoryResponse = await _supabase
          .from('inventory')
          .select('id, name, category, quantity, unit, supplier');

      if (inventoryResponse.isNotEmpty) {
        int total = 0;
        int lowStock = 0;
        int outOfStock = 0;
        Map<String, Map<String, int>> healthByCategory = {};
        List<Map<String, dynamic>> critical = [];

        for (var item in inventoryResponse) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final category = item['category']?.toString() ?? 'Other';
          total++;

          healthByCategory.putIfAbsent(category, () => {'good': 0, 'low': 0, 'out': 0});

          if (quantity == 0) {
            outOfStock++;
            critical.add(item);
            healthByCategory[category]!['out'] = healthByCategory[category]!['out']! + 1;
          } else if (quantity < 10) {
            lowStock++;
            critical.add(item);
            healthByCategory[category]!['low'] = healthByCategory[category]!['low']! + 1;
          } else {
            healthByCategory[category]!['good'] = healthByCategory[category]!['good']! + 1;
          }
        }

        final activityResponse = await _supabase
            .from('stock_transactions')
            .select()
            .order('created_at', ascending: false)
            .limit(5);

        final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        int startDay = (_selectedWeek - 1) * 7 + 1;
        int endDay = _selectedWeek * 7;
        if (_selectedWeek == 4) endDay = lastDayOfMonth;
        if (startDay > lastDayOfMonth) startDay = lastDayOfMonth;

        final startDate = DateTime(_selectedYear, _selectedMonth, startDay, 0, 0, 0).toUtc().toIso8601String();
        final endDate = DateTime(_selectedYear, _selectedMonth, endDay, 23, 59, 59).toUtc().toIso8601String();

        final requestsResponse = await _supabase
            .from('kitchen_requests')
            .select('item_name, quantity_needed')
            .eq('status', 'Approved')
            .gte('created_at', startDate)
            .lte('created_at', endDate);

        Map<String, int> topItemsMap = {};
        for (var req in requestsResponse) {
          final name = req['item_name']?.toString() ?? 'Unknown';
          final qty = (req['quantity_needed'] as num?)?.toInt() ?? 0;
          topItemsMap[name] = (topItemsMap[name] ?? 0) + qty;
        }

        var sortedTopItems = topItemsMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (mounted) {
          // Identify newly critical items that haven't been alerted yet
          final currentCriticalIds = critical
              .map((e) => (e['id']?.toString() ?? e['name']?.toString() ?? ''))
              .where((id) => id.isNotEmpty)
              .toSet();
          final hasNewCriticalItems = currentCriticalIds.difference(_previouslyAlertedCriticalIds).isNotEmpty;

          setState(() {
            _totalInventoryItems = total;
            _lowStockItems = lowStock;
            _outOfStockItems = outOfStock;
            _inventoryHealthByCategory = healthByCategory;
            _criticalItems = critical;
            _recentActivity = List<Map<String, dynamic>>.from(activityResponse);
            _topRequestedItems = sortedTopItems.take(5).map((e) => {'name': e.key, 'value': e.value}).toList();
            _isLoading = false;
          });

          // Trigger alert if there are newly critical items
          if (critical.isNotEmpty && hasNewCriticalItems) {
            _previouslyAlertedCriticalIds = currentCriticalIds;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCriticalStockPopup();
            });
          } else if (critical.isEmpty) {
            _previouslyAlertedCriticalIds.clear();
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: 12),
              Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from the Inventory Management System?',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14332E),
                foregroundColor: const Color(0xFFE6C374),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/staff-login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getPages() {
    return [
      _buildDashboardPage(),
      _buildKitchenRequestsPage(),
      const InventoryPage(),
      InventoryRoomPage(key: InventoryRoomPage.globalKey),
      const PettyCashExpensePage(),
      const SpoilageWastagePage(embedded: true),
    ];
  }

  // -------------------------------------------------------------
  // DASHBOARD PAGE
  // -------------------------------------------------------------
  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF14332E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 16),
            _buildCriticalAlerts(),
            _buildDashboardToolbar(),
            const SizedBox(height: 24),
            _buildInventoryInsights(),
            const SizedBox(height: 24),
            _buildActivityFeed(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final now = DateTime.now();
    String greeting = 'Magandang Araw';
    if (now.hour < 12) {
      greeting = 'Magandang Umaga';
    } else if (now.hour < 18) {
      greeting = 'Magandang Hapon';
    } else {
      greeting = 'Magandang Gabi';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2C27),
            Color(0xFF14332E),
            Color(0xFF1D4A41),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF28564D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2C27).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -15,
            child: Icon(
              Icons.warehouse_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C374).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFFE6C374), size: 13),
                        SizedBox(width: 6),
                        Text(
                          'Pagsanjan Inventory Command',
                          style: TextStyle(
                            color: Color(0xFFE6C374),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM dd, yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '$greeting,',
                style: const TextStyle(
                  color: Color(0xFFB0C8C3),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_userName!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitor live ingredient stocks, incoming kitchen orders, and room transfers.',
                style: TextStyle(
                  color: Color(0xFFD1E0DC),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                const Text(
                  'Inventory Overview',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildFlatStatsRow(isNarrow: true),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Quick Navigation',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildFlatActionsRow(isNarrow: true),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildFlatStatsRow(isNarrow: false)),
                    const SizedBox(width: 20),
                    _buildFlatActionsRow(isNarrow: false),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlatStatsRow({required bool isNarrow}) {
    final items = [
      _buildStatTile('Total Items', _totalInventoryItems.toString(), const Color(0xFF14332E), Icons.inventory_2_rounded),
      _buildStatTile('Low Stock', _lowStockItems.toString(), const Color(0xFFF59E0B), Icons.warning_amber_rounded),
      _buildStatTile('Out of Stock', _outOfStockItems.toString(), const Color(0xFFEF4444), Icons.cancel_rounded),
    ];

    if (isNarrow) {
      return SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: items.map((e) => Container(width: 140, margin: const EdgeInsets.only(right: 8), child: e)).toList(),
        ),
      );
    }

    return Row(
      children: items.map((e) => Expanded(child: e)).toList(),
    );
  }

  Widget _buildStatTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatActionsRow({required bool isNarrow}) {
    final actions = [
      _buildFlatActionButton('Requests', Icons.shopping_bag_outlined, const Color(0xFF14332E), () => _onItemTapped(1)),
      _buildFlatActionButton('Inventory', Icons.edit_note_rounded, const Color(0xFF0284C7), () => _onItemTapped(2)),
      _buildFlatActionButton('Storage', Icons.warehouse_rounded, const Color(0xFFD97706), () => _onItemTapped(3)),
    ];

    if (isNarrow) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: actions.map((e) => Padding(padding: const EdgeInsets.only(right: 8), child: e)).toList(),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: e)).toList(),
    );
  }

  Widget _buildFlatActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalAlerts() {
    if (_criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: const Text(
                  'Critical Stock Attention Required',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _showAllCriticalItemsModal,
                icon: const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFDC2626)),
                label: Text(
                  'View All (${_criticalItems.length})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _criticalItems.length,
              itemBuilder: (context, index) {
                final item = _criticalItems[index];
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final isOut = qty == 0;
                final tagColor = isOut ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

                return Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tagColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOut ? 'OUT OF STOCK' : 'Only $qty left',
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryInsights() {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14332E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF14332E), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inventory Analytics & Insights',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Department health metrics & kitchen consumption velocity',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE SYNC',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isMobile) ...[
          _buildInventoryHealthChart(),
          const SizedBox(height: 14),
          _buildTopRequestedItemsChart(),
        ] else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildInventoryHealthChart()),
                const SizedBox(width: 14),
                Expanded(child: _buildTopRequestedItemsChart()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInventoryHealthChart() {
    double maxY = 0;
    int totalGood = 0;
    int totalLow = 0;
    int totalOut = 0;

    for (var value in _inventoryHealthByCategory.values) {
      final good = value['good'] ?? 0;
      final low = value['low'] ?? 0;
      final out = value['out'] ?? 0;
      final total = good + low + out;
      if (total > maxY) maxY = total.toDouble();

      totalGood += good;
      totalLow += low;
      totalOut += out;
    }
    final totalItems = totalGood + totalLow + totalOut;
    final healthRate = totalItems > 0 ? ((totalGood / totalItems) * 100).round() : 100;

    maxY = maxY + (maxY * 0.2).ceil();
    if (maxY < 5) maxY = 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF059669), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category Stock Health',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_inventoryHealthByCategory.length} departments',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartTypeToggle(
                    isLine: _isLineChartForHealth,
                    onToggle: (val) => setState(() => _isLineChartForHealth = val),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '$healthRate% Optimal',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_inventoryHealthByCategory.isEmpty)
            _buildChartEmptyState(Icons.bar_chart_rounded, 'No Category Data', 'Stock metrics will display once inventory is added.')
          else if (_isLineChartForHealth)
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final categoryNames = _inventoryHealthByCategory.keys.toList();
                          final index = value.toInt();
                          if (index >= 0 && index < categoryNames.length) {
                            String text = categoryNames[index];
                            if (text.length > 8) text = '${text.substring(0, 7)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (_inventoryHealthByCategory.length > 1 ? _inventoryHealthByCategory.length - 1 : 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF0F172A),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final category = _inventoryHealthByCategory.keys.toList()[spot.x.toInt()];
                          final values = _inventoryHealthByCategory[category]!;
                          return LineTooltipItem(
                            '$category\n',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            children: [
                              TextSpan(text: '🟢 Optimal: ${values['good']}\n', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11.5, fontWeight: FontWeight.w600)),
                              TextSpan(text: '🟠 Low: ${values['low']}\n', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5, fontWeight: FontWeight.w600)),
                              TextSpan(text: '🔴 Out: ${values['out']}', style: const TextStyle(color: Color(0xFFF87171), fontSize: 11.5, fontWeight: FontWeight.w600)),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _inventoryHealthByCategory.entries.map((e) {
                        final index = _inventoryHealthByCategory.keys.toList().indexOf(e.key);
                        return FlSpot(index.toDouble(), (e.value['good'] ?? 0).toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF10B981),
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4.5,
                          color: const Color(0xFF10B981),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.25),
                            const Color(0xFF10B981).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF0F172A),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = _inventoryHealthByCategory.keys.toList()[group.x.toInt()];
                        final values = _inventoryHealthByCategory[category]!;
                        return BarTooltipItem(
                          '$category\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(text: '🟢 Good: ${values['good']}\n', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11.5, fontWeight: FontWeight.w600)),
                            TextSpan(text: '🟠 Low: ${values['low']}\n', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5, fontWeight: FontWeight.w600)),
                            TextSpan(text: '🔴 Out: ${values['out']}', style: const TextStyle(color: Color(0xFFF87171), fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final categoryNames = _inventoryHealthByCategory.keys.toList();
                          final index = value.toInt();
                          if (index >= 0 && index < categoryNames.length) {
                            String text = categoryNames[index];
                            if (text.length > 8) text = '${text.substring(0, 7)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _inventoryHealthByCategory.entries.map((e) {
                    final index = _inventoryHealthByCategory.keys.toList().indexOf(e.key);
                    final good = e.value['good']!.toDouble();
                    final low = e.value['low']!.toDouble();
                    final out = e.value['out']!.toDouble();
                    final total = good + low + out;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: const Color(0xFFF8FAFC),
                          ),
                          rodStackItems: [
                            BarChartRodStackItem(0, good, const Color(0xFF10B981)),
                            BarChartRodStackItem(good, good + low, const Color(0xFFF59E0B)),
                            BarChartRodStackItem(good + low, total, const Color(0xFFEF4444)),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Rich Status Legend Badges with Counts
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMetricLegendPill(
                color: const Color(0xFF10B981),
                label: 'Optimal',
                count: totalGood,
              ),
              const SizedBox(width: 10),
              _buildMetricLegendPill(
                color: const Color(0xFFF59E0B),
                label: 'Low Stock',
                count: totalLow,
              ),
              const SizedBox(width: 10),
              _buildMetricLegendPill(
                color: const Color(0xFFEF4444),
                label: 'Out of Stock',
                count: totalOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRequestedItemsChart() {
    double maxX = 0;
    double totalDispatched = 0;
    for (var item in _topRequestedItems) {
      final val = (item['value'] as num).toDouble();
      if (val > maxX) maxX = val;
      totalDispatched += val;
    }
    maxX = maxX + (maxX * 0.2).ceil();
    if (maxX < 5) maxX = 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFF0284C7), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Kitchen Requests',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Fastest-moving items',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartTypeToggle(
                    isLine: _isLineChartForRequests,
                    onToggle: (val) => setState(() => _isLineChartForRequests = val),
                  ),
                  const SizedBox(width: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      _buildFilterDropdown<int>(
                        value: _selectedMonth,
                        items: List.generate(12, (index) => index + 1),
                        label: 'Month',
                        itemBuilder: (val) => DateFormat('MMM').format(DateTime(2000, val)),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonth = val);
                            _loadDashboardData();
                          }
                        },
                      ),
                      _buildFilterDropdown<int>(
                        value: _selectedWeek,
                        items: [1, 2, 3, 4],
                        label: 'Week',
                        itemBuilder: (val) => 'Wk $val',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWeek = val);
                            _loadDashboardData();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_topRequestedItems.isEmpty)
            _buildChartEmptyState(Icons.trending_up_outlined, 'No Requests Found', 'Top kitchen items for this timeframe will appear here.')
          else if (_isLineChartForRequests)
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _topRequestedItems.length) {
                            String name = _topRequestedItems[index]['name'];
                            if (name.length > 8) name = '${name.substring(0, 7)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (_topRequestedItems.length > 1 ? _topRequestedItems.length - 1 : 1).toDouble(),
                  minY: 0,
                  maxY: maxX,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF0F172A),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final item = _topRequestedItems[index];
                          return LineTooltipItem(
                            '#${index + 1} ${item['name']}\n',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            children: [
                              TextSpan(
                                text: 'Dispatched: ${NumberFormat('#,###').format(spot.y)} units',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _topRequestedItems.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF0284C7),
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF0284C7),
                          strokeWidth: 2.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.25),
                            const Color(0xFF0284C7).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxX,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF0F172A),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = _topRequestedItems[groupIndex];
                        return BarTooltipItem(
                          '#${groupIndex + 1} ${item['name']}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          children: [
                            TextSpan(
                              text: 'Dispatched: ${NumberFormat('#,###').format(item['value'])} units',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _topRequestedItems.length) {
                            String name = _topRequestedItems[index]['name'];
                            if (name.length > 8) name = '${name.substring(0, 7)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _topRequestedItems.asMap().entries.map((e) {
                    final index = e.key;
                    final val = (e.value['value'] as num).toDouble();
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxX,
                            color: const Color(0xFFF8FAFC),
                          ),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F2621), Color(0xFF1B4D3E), Color(0xFF2D6A4F)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Peak Velocity: ${NumberFormat('#,###').format(totalDispatched)} total units dispatched to kitchen',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeToggle({
    required bool isLine,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onToggle(false),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: !isLine ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: !isLine
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 14,
                    color: !isLine ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bar',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: !isLine ? FontWeight.w800 : FontWeight.w600,
                      color: !isLine ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => onToggle(true),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isLine ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isLine
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 14,
                    color: isLine ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Line',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isLine ? FontWeight.w800 : FontWeight.w600,
                      color: isLine ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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

  Widget _buildMetricLegendPill({
    required Color color,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    String Function(T)? itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemBuilder != null ? itemBuilder(item) : item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChartEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFF14332E), size: 20),
                SizedBox(width: 8),
                Text(
                  'Recent Stock Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            if (_recentActivity.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_recentActivity.length} records',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14332E),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _recentActivity.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text(
                          'No recent activity recorded',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final act = _recentActivity[index];
                    final type = act['transaction_type']?.toString() ?? 'unknown';
                    final date = DateTime.parse(act['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String()).toLocal();
                    final isIncoming = type == 'incoming';
                    final accentColor = isIncoming ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: accentColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act['item_name'] ?? 'Unknown Item',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  act['purpose'] ?? 'Stock update',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isIncoming ? '+' : '-'}${act['quantity']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('h:mm a').format(date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAllCriticalItemsModal() {
    _showCriticalStockPopup();
  }

  void _showCriticalStockPopup() {
    final outOfStockItems = _criticalItems.where((item) => ((item['quantity'] as num?)?.toDouble() ?? 0) <= 0).toList();
    final lowStockItems = _criticalItems.where((item) => ((item['quantity'] as num?)?.toDouble() ?? 0) > 0).toList();

    String activeFilter = 'all'; // 'all' | 'out_of_stock' | 'low_stock'

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<Map<String, dynamic>> displayedItems;
            if (activeFilter == 'out_of_stock') {
              displayedItems = outOfStockItems;
            } else if (activeFilter == 'low_stock') {
              displayedItems = lowStockItems;
            } else {
              displayedItems = _criticalItems;
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 32),
              child: Container(
                width: 540,
                constraints: BoxConstraints(
                  maxWidth: 540,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header (Executive Theme) ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 22, isMobile ? 16 : 20, isMobile ? 12 : 16, isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0C241F), Color(0xFF143A32)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 18 : 24)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD97706).withValues(alpha: 0.40),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFFFBBF24),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Critical Stock Alerts',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        'ACTION REQUIRED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFCA5A5),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _criticalItems.length == 1
                                      ? '1 ingredient is below safety threshold'
                                      : '${_criticalItems.length} ingredients require replenishment before kitchen prep',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // ── Interactive Segmented Filter Chips ────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterTab(
                              label: 'All Critical',
                              count: _criticalItems.length,
                              isSelected: activeFilter == 'all',
                              accentColor: const Color(0xFF0F172A),
                              onTap: () => setModalState(() => activeFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterTab(
                              label: 'Out of Stock',
                              count: outOfStockItems.length,
                              isSelected: activeFilter == 'out_of_stock',
                              accentColor: const Color(0xFFDC2626),
                              onTap: () => setModalState(() => activeFilter = 'out_of_stock'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterTab(
                              label: 'Low Stock Buffer',
                              count: lowStockItems.length,
                              isSelected: activeFilter == 'low_stock',
                              accentColor: const Color(0xFFD97706),
                              onTap: () => setModalState(() => activeFilter = 'low_stock'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Items List ─────────────────────────────────────────
                    Flexible(
                      child: displayedItems.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 44),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No items in this filter',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
                              itemCount: displayedItems.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final item = displayedItems[i];
                                final isOut = ((item['quantity'] as num?)?.toDouble() ?? 0) <= 0;
                                return _buildCriticalItemTile(item, isOutOfStock: isOut);
                              },
                            ),
                    ),

                    // ── Footer with direct Navigation ─────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 12, isMobile ? 14 : 20, isMobile ? 14 : 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(isMobile ? 18 : 24)),
                        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: isMobile
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDC2626),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${outOfStockItems.length} out of stock',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Dismiss',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          PurchaseOrderGeneratorDialog.show(
                                            context,
                                            criticalItems: _criticalItems,
                                            onGoToStorageRoom: () {
                                              _onItemTapped(3);
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                InventoryRoomPage.navigateToIncomingTab(context);
                                              });
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFD97706)),
                                        label: Text(
                                          'Generate PO',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: const Color(0xFF0C241F),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _onItemTapped(2); // Go to Inventory management tab
                                        },
                                        icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD9A441)),
                                        label: Text(
                                          'Manage Inv',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0C241F),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDC2626),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${outOfStockItems.length} out of stock',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Dismiss',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    PurchaseOrderGeneratorDialog.show(
                                      context,
                                      criticalItems: _criticalItems,
                                      onGoToStorageRoom: () {
                                        _onItemTapped(3);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          InventoryRoomPage.navigateToIncomingTab(context);
                                        });
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFD97706)),
                                  label: Text(
                                    'Generate PO',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: const Color(0xFF0C241F),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _onItemTapped(2); // Go to Inventory management tab
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFD9A441)),
                                  label: Text(
                                    'Manage Inventory',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0C241F),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
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
      },
    );
  }

  Widget _buildFilterTab({
    required String label,
    required int count,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFCBD5E1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : accentColor,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalItemTile(Map<String, dynamic> item, {required bool isOutOfStock}) {
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final minQty = (item['min_quantity'] as num?)?.toDouble() ?? (item['threshold'] as num?)?.toDouble() ?? 5.0;
    final unit = (item['unit'] as String?) ?? 'kg';
    final category = (item['category'] as String?) ?? 'General';
    final name = (item['name'] as String?) ?? 'Unnamed Item';

    final Color statusColor = isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final String statusText = isOutOfStock ? '0.00 $unit left' : '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit left';

    IconData categoryIcon = Icons.inventory_2_outlined;
    final catLower = category.toLowerCase();
    if (catLower.contains('meat') || catLower.contains('beef') || catLower.contains('pork') || catLower.contains('chicken')) {
      categoryIcon = Icons.restaurant_rounded;
    } else if (catLower.contains('fresh') || catLower.contains('veg') || catLower.contains('fruit')) {
      categoryIcon = Icons.eco_rounded;
    } else if (catLower.contains('sauce') || catLower.contains('condiment') || catLower.contains('spice')) {
      categoryIcon = Icons.soup_kitchen_rounded;
    } else if (catLower.contains('beverage') || catLower.contains('drink')) {
      categoryIcon = Icons.local_drink_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutOfStock ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),

          // Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    Text(
                      '• Min: ${minQty.toStringAsFixed(0)} $unit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge + Quick Restock Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOutOfStock ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOutOfStock ? 'OUT OF STOCK' : statusText,
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  _onItemTapped(2); // Go to inventory tab
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, size: 11, color: Color(0xFF0F766E)),
                      const SizedBox(width: 2),
                      Text(
                        'Restock',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // KITCHEN REQUESTS PAGE
  // -------------------------------------------------------------
  Widget _buildKitchenRequestsPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF14332E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Bulk Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2C27), Color(0xFF14332E), Color(0xFF1D4A41)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF28564D), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F2C27).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ResponsiveUtils.isMobile(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFE6C374), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kitchen Stock Requests',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Authorize requisitions from kitchen team',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFB0C8C3)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _approveAllRequests,
                                icon: const Icon(Icons.done_all_rounded, size: 15),
                                label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _rejectAllRequests,
                                icon: const Icon(Icons.cancel_outlined, size: 15),
                                label: const Text('Reject All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFF87171),
                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFE6C374), size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kitchen Stock Requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Review and authorize item requisitions dispatched by the kitchen team',
                                style: TextStyle(fontSize: 12, color: Color(0xFFB0C8C3)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _approveAllRequests,
                              icon: const Icon(Icons.done_all_rounded, size: 16),
                              label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _rejectAllRequests,
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Reject All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF87171),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Requests List with Stream
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _allRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF14332E))),
                  );
                }

                final requests = snapshot.data ?? [];

                List<Map<String, dynamic>> filteredRequests;
                switch (_requestFilter) {
                  case 1:
                    filteredRequests = requests.where((r) => r['status'] == 'Pending').toList();
                    break;
                  case 2:
                    filteredRequests = requests.where((r) => r['status'] == 'Approved').toList();
                    break;
                  case 3:
                    filteredRequests = requests.where((r) => r['status'] == 'Rejected').toList();
                    break;
                  default:
                    filteredRequests = requests;
                }

                filteredRequests.sort((a, b) {
                  final statusA = a['status']?.toString() ?? 'Pending';
                  final statusB = b['status']?.toString() ?? 'Pending';
                  final priorityA = statusA == 'Pending' ? 1 : statusA == 'Approved' ? 2 : 3;
                  final priorityB = statusB == 'Pending' ? 1 : statusB == 'Approved' ? 2 : 3;
                  if (priorityA != priorityB) return priorityA.compareTo(priorityB);

                  final createdAtA = DateTime.parse(a['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String());
                  final createdAtB = DateTime.parse(b['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String());
                  return createdAtB.compareTo(createdAtA);
                });

                final pendingCount = requests.where((r) => r['status'] == 'Pending').length;
                final approvedCount = requests.where((r) => r['status'] == 'Approved').length;
                final rejectedCount = requests.where((r) => r['status'] == 'Rejected').length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segment Filter Tabs
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ResponsiveUtils.isMobile(context)
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: List.generate(_requestFilterLabels.length, (index) {
                                  final isSelected = _requestFilter == index;
                                  int count;
                                  switch (index) {
                                    case 0:
                                      count = requests.length;
                                      break;
                                    case 1:
                                      count = pendingCount;
                                      break;
                                    case 2:
                                      count = approvedCount;
                                      break;
                                    case 3:
                                      count = rejectedCount;
                                      break;
                                    default:
                                      count = 0;
                                  }

                                  return Padding(
                                    padding: EdgeInsets.only(right: index == _requestFilterLabels.length - 1 ? 0 : 6),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _requestFilter = index;
                                          _currentPage = 1;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF14332E) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF14332E).withValues(alpha: 0.25),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _requestFilterLabels[index],
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFFE6C374)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  color: isSelected ? const Color(0xFF14332E) : const Color(0xFF475569),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            )
                          : Row(
                              children: List.generate(_requestFilterLabels.length, (index) {
                                final isSelected = _requestFilter == index;
                                int count;
                                switch (index) {
                                  case 0:
                                    count = requests.length;
                                    break;
                                  case 1:
                                    count = pendingCount;
                                    break;
                                  case 2:
                                    count = approvedCount;
                                    break;
                                  case 3:
                                    count = rejectedCount;
                                    break;
                                  default:
                                    count = 0;
                                }

                                return Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _requestFilter = index;
                                        _currentPage = 1;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF14332E) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF14332E).withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _requestFilterLabels[index],
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFE6C374)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFF14332E) : const Color(0xFF475569),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
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
                    const SizedBox(height: 14),

                    // Cards Grid / List
                    if (filteredRequests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No ${_requestFilterLabels[_requestFilter]} requests found',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Requests from staff and chef will appear here',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final totalPages = (filteredRequests.length / _itemsPerPage).ceil();
                          final startIndex = (_currentPage - 1) * _itemsPerPage;
                          final endIndex = startIndex + _itemsPerPage;
                          final paginatedRequests = filteredRequests.sublist(
                            startIndex,
                            endIndex > filteredRequests.length ? filteredRequests.length : endIndex,
                          );

                          int crossAxisCount = constraints.maxWidth < 700 ? 1 : (constraints.maxWidth < 1200 ? 2 : 3);

                          return Column(
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.7,
                                ),
                                itemCount: paginatedRequests.length,
                                itemBuilder: (context, index) {
                                  return _buildRequestCard(paginatedRequests[index]);
                                },
                              ),
                              if (totalPages > 1) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                        color: const Color(0xFF14332E),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Page $_currentPage of $totalPages',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                        color: const Color(0xFF14332E),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'Pending';
    final priority = request['priority']?.toString() ?? 'Normal';
    final itemName = request['item_name']?.toString() ?? 'Unknown';
    final quantity = request['quantity_needed']?.toString() ?? '0';
    final unit = (request['unit']?.toString() ?? 'pcs').toUpperCase();
    final requestedBy = request['requested_by']?.toString() ?? 'Staff';
    final createdAt = request['created_at']?.toString();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
    }

    Color priorityColor;
    switch (priority) {
      case 'Urgent':
        priorityColor = const Color(0xFFEF4444);
        break;
      case 'High':
        priorityColor = const Color(0xFFF59E0B);
        break;
      case 'Low':
        priorityColor = const Color(0xFF0284C7);
        break;
      default:
        priorityColor = const Color(0xFF64748B);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Item Name + Status Pill + Priority
            Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle: Quantity Callout + Requested By + Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14332E).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.15)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$quantity ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: unit,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14332E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              requestedBy,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(createdAt),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom: Action Buttons or Audit Badge
            if (status == 'Pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _handleRequestAction(request['id'], 'Approved'),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _handleRequestAction(request['id'], 'Rejected'),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Processed ${_formatDateTime(request['updated_at']?.toString() ?? createdAt)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Future<void> _handleRequestAction(String requestId, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      if (newStatus == 'Approved') {
        final request = await _supabase
            .from('kitchen_requests')
            .select()
            .eq('id', requestId)
            .single();

        final itemName = request['item_name']?.toString();
        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

        if (itemName != null) {
          if (quantityNeeded == 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot approve: Requested quantity is 0.'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            return;
          }

          final inventoryItems = await _supabase
              .from('inventory')
              .select('id, quantity')
              .ilike('name', '%$itemName%')
              .limit(1);

          if (inventoryItems.isNotEmpty) {
            final inventoryItem = inventoryItems.first;
            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;

            if (currentQuantity >= quantityNeeded) {
              await _approveRequestCore(request);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request approved and stock transferred to kitchen!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot approve: Insufficient stock. Only $currentQuantity available, $quantityNeeded needed.'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
              return;
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot approve: Item not found in inventory.'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            return;
          }
        }
      } else {
        final request = await _supabase
            .from('kitchen_requests')
            .select()
            .eq('id', requestId)
            .maybeSingle();

        await _supabase
            .from('kitchen_requests')
            .update({'status': newStatus})
            .eq('id', requestId);

        final itemName = request?['item_name']?.toString() ?? 'Stock item';
        final qty = request?['quantity_needed']?.toString() ?? '';
        final unit = request?['unit']?.toString() ?? '';

        await NotificationService.sendNotification(
          isForAdmin: true,
          actorName: 'Pagsanjan Inv',
          actionType: 'stock_rejected',
          reservationId: 'Kitchen',
          eventType: 'Stock Request Declined: $itemName ($qty $unit)',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request rejected.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _allRequestsStream = _supabase
              .from('kitchen_requests')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false);
        });
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequestCore(Map<String, dynamic> request, {bool skipNotification = false}) async {
    final itemName = request['item_name']?.toString();
    final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

    if (itemName != null && quantityNeeded > 0) {
      final inventoryItems = await _supabase
          .from('inventory')
          .select('id, quantity, category')
          .ilike('name', '%$itemName%')
          .limit(1);

      if (inventoryItems.isNotEmpty) {
        final inventoryItem = inventoryItems.first;
        final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
        final transferQty = quantityNeeded > currentQuantity ? currentQuantity : quantityNeeded;

        final newInventoryQuantity = currentQuantity - transferQty;
        await _supabase
            .from('inventory')
            .update({'quantity': newInventoryQuantity})
            .eq('id', inventoryItem['id']);

        final kitchenItems = await _supabase
            .from('kitchen_inventory')
            .select('id, quantity')
            .ilike('name', '%$itemName%')
            .limit(1);

        int newKitchenQuantity;
        if (kitchenItems.isNotEmpty) {
          final kitchenItem = kitchenItems.first;
          final currentKitchenQuantity = (kitchenItem['quantity'] as num?)?.toInt() ?? 0;
          newKitchenQuantity = currentKitchenQuantity + transferQty;
          await _supabase
              .from('kitchen_inventory')
              .update({'quantity': newKitchenQuantity})
              .eq('id', kitchenItem['id']);
        } else {
          newKitchenQuantity = transferQty;
          await _supabase.from('kitchen_inventory').insert({
            'name': itemName,
            'quantity': newKitchenQuantity,
            'unit': request['unit'] ?? 'pcs',
            'category': inventoryItem['category'] ?? 'General',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }

        final reqBy = request['requested_by']?.toString();
        final requestedBy = (reqBy != null && reqBy.isNotEmpty) ? reqBy : 'chef';

        await _supabase.from('stock_transactions').insert({
          'item_name': itemName,
          'transaction_type': 'outgoing',
          'quantity': transferQty,
          'unit': request['unit'] ?? 'pcs',
          'processed_by': _userName,
          'requested_by': requestedBy,
          'purpose': 'Transferred to kitchen (Request #${request['id']})',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        await _supabase
            .from('kitchen_requests')
            .update({'status': 'Approved'})
            .eq('id', request['id']);

        if (!skipNotification) {
          await NotificationService.sendNotification(
            isForAdmin: true,
            actorName: 'Pagsanjan Inv',
            actionType: 'stock_approved',
            reservationId: 'Kitchen',
            eventType: 'Stock Approved: $itemName ($transferQty ${request['unit'] ?? ''})',
          );
        }
      }
    }
  }

  Future<void> _approveAllRequests() async {
    setState(() => _isLoading = true);
    try {
      NotificationService.setBulkOperation(true);

      // Fetch pending requests, main inventory, and kitchen inventory in parallel
      final results = await Future.wait([
        _supabase.from('kitchen_requests').select().eq('status', 'Pending'),
        _supabase.from('inventory').select('id, name, quantity, category, unit'),
        _supabase.from('kitchen_inventory').select('id, name, quantity, category, unit'),
      ]);

      final pendingRequests = List<Map<String, dynamic>>.from(results[0] as List);
      final inventoryItems = List<Map<String, dynamic>>.from(results[1] as List);
      final kitchenItems = List<Map<String, dynamic>>.from(results[2] as List);

      if (pendingRequests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending requests to approve.')),
          );
        }
        setState(() => _isLoading = false);
        NotificationService.setBulkOperation(false);
        return;
      }

      // Index inventory and kitchen inventory by normalized name
      final Map<String, Map<String, dynamic>> inventoryMap = {};
      for (final item in inventoryItems) {
        final name = (item['name']?.toString() ?? '').toLowerCase().trim();
        if (name.isNotEmpty) inventoryMap[name] = Map<String, dynamic>.from(item);
      }

      final Map<String, Map<String, dynamic>> kitchenMap = {};
      for (final item in kitchenItems) {
        final name = (item['name']?.toString() ?? '').toLowerCase().trim();
        if (name.isNotEmpty) kitchenMap[name] = Map<String, dynamic>.from(item);
      }

      final List<dynamic> approvedIds = [];
      final List<Map<String, dynamic>> transactionsToInsert = [];
      final Set<String> modifiedInventoryNames = {};
      final Set<String> modifiedKitchenNames = {};
      int outOfStockCount = 0;

      final nowUtc = DateTime.now().toUtc().toIso8601String();

      for (final request in pendingRequests) {
        final reqName = (request['item_name']?.toString() ?? '').trim();
        final reqNameKey = reqName.toLowerCase();
        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

        if (reqName.isEmpty || quantityNeeded <= 0) continue;

        // Find matching inventory item (exact or partial match)
        Map<String, dynamic>? invItem = inventoryMap[reqNameKey];
        if (invItem == null) {
          final matchKey = inventoryMap.keys.firstWhere(
            (k) => k.contains(reqNameKey) || reqNameKey.contains(k),
            orElse: () => '',
          );
          if (matchKey.isNotEmpty) invItem = inventoryMap[matchKey];
        }

        if (invItem != null) {
          final currentInvQty = (invItem['quantity'] as num?)?.toInt() ?? 0;

          if (currentInvQty >= quantityNeeded) {
            final transferQty = quantityNeeded;
            invItem['quantity'] = currentInvQty - transferQty;
            modifiedInventoryNames.add(invItem['name'].toString().toLowerCase().trim());

            // Update or create kitchen item in memory
            final kKey = invItem['name'].toString().toLowerCase().trim();
            if (kitchenMap.containsKey(kKey)) {
              final kItem = kitchenMap[kKey]!;
              final currentKQty = (kItem['quantity'] as num?)?.toInt() ?? 0;
              kItem['quantity'] = currentKQty + transferQty;
              modifiedKitchenNames.add(kKey);
            } else {
              kitchenMap[kKey] = {
                'name': invItem['name'],
                'quantity': transferQty,
                'unit': request['unit'] ?? invItem['unit'] ?? 'pcs',
                'category': invItem['category'] ?? 'General',
                'is_new': true,
              };
              modifiedKitchenNames.add(kKey);
            }

            approvedIds.add(request['id']);

            final itemReqBy = request['requested_by']?.toString();
            final safeReqBy = (itemReqBy != null && itemReqBy.isNotEmpty) ? itemReqBy : 'chef';

            transactionsToInsert.add({
              'item_name': invItem['name'],
              'transaction_type': 'outgoing',
              'quantity': transferQty,
              'unit': request['unit'] ?? invItem['unit'] ?? 'pcs',
              'processed_by': _userName,
              'requested_by': safeReqBy,
              'purpose': 'Bulk Transferred to kitchen (Request #${request['id']})',
              'created_at': nowUtc,
            });
          } else {
            outOfStockCount++;
          }
        } else {
          outOfStockCount++;
        }
      }

      final approvedCount = approvedIds.length;

      if (approvedCount > 0) {
        // Execute batch database updates in parallel
        final List<Future<dynamic>> batchOps = [];

        // 1. Bulk update all approved kitchen_requests
        batchOps.add(
          _supabase
              .from('kitchen_requests')
              .update({'status': 'Approved'})
              .inFilter('id', approvedIds),
        );

        // 2. Bulk insert stock transactions
        if (transactionsToInsert.isNotEmpty) {
          batchOps.add(_supabase.from('stock_transactions').insert(transactionsToInsert));
        }

        // 3. Update main inventory items
        for (final nameKey in modifiedInventoryNames) {
          final item = inventoryMap[nameKey]!;
          batchOps.add(
            _supabase
                .from('inventory')
                .update({'quantity': item['quantity']})
                .eq('id', item['id']),
          );
        }

        // 4. Update or insert kitchen inventory items
        for (final nameKey in modifiedKitchenNames) {
          final item = kitchenMap[nameKey]!;
          if (item['is_new'] == true) {
            batchOps.add(
              _supabase.from('kitchen_inventory').insert({
                'name': item['name'],
                'quantity': item['quantity'],
                'unit': item['unit'],
                'category': item['category'],
                'updated_at': nowUtc,
              }),
            );
          } else {
            batchOps.add(
              _supabase
                  .from('kitchen_inventory')
                  .update({'quantity': item['quantity']})
                  .eq('id', item['id']),
            );
          }
        }

        await Future.wait(batchOps);

        // Send single consolidated notification to kitchen
        await NotificationService.sendNotification(
          isForAdmin: true,
          actorName: 'Pagsanjan Inv',
          actionType: 'stock_approved',
          reservationId: 'Kitchen',
          eventType: 'Stock Approved: $approvedCount item${approvedCount == 1 ? '' : 's'}',
        );
      }

      NotificationService.setBulkOperation(false);

      if (mounted) {
        setState(() {
          _allRequestsStream = _supabase
              .from('kitchen_requests')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false);
        });

        String message;
        Color backgroundColor;

        if (approvedCount > 0 && outOfStockCount > 0) {
          message = 'Approved $approvedCount requests! $outOfStockCount remain pending (insufficient stock).';
          backgroundColor = AppTheme.warningOrange;
        } else if (approvedCount > 0) {
          message = 'Approved all $approvedCount requests!';
          backgroundColor = AppTheme.successGreen;
        } else {
          message = 'Cannot approve: Insufficient stock for all pending items in inventory.';
          backgroundColor = AppTheme.errorRed;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: backgroundColor),
        );
      }

      _loadDashboardData();
    } catch (e) {
      NotificationService.setBulkOperation(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      NotificationService.setBulkOperation(false);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectAllRequests() async {
    setState(() => _isLoading = true);
    try {
      final pendingRequests = await _supabase
          .from('kitchen_requests')
          .select('id, item_name')
          .eq('status', 'Pending');

      final count = pendingRequests.length;
      if (count == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending requests to reject.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Fast, atomic single-query bulk update for ALL pending records
      await _supabase
          .from('kitchen_requests')
          .update({'status': 'Rejected'})
          .eq('status', 'Pending');

      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: 'Pagsanjan Inv',
        actionType: 'stock_rejected',
        reservationId: 'Kitchen',
        eventType: 'Stock Requests Declined: $count item(s)',
      );

      if (mounted) {
        setState(() {
          _allRequestsStream = _supabase
              .from('kitchen_requests')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected $count requests successfully!'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }

      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------
  // LAYOUT
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF14332E),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFFE6C374),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pagsanjan Inventory',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC7D6D3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    children: [
                      _buildCompactSidebarItem(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
                      _buildCompactSidebarItem(icon: Icons.shopping_bag_rounded, title: 'Kitchen Requests', index: 1),
                      _buildCompactSidebarItem(icon: Icons.inventory_2_rounded, title: 'Manage Inventory', index: 2),
                      _buildCompactSidebarItem(icon: Icons.warehouse_rounded, title: 'Storage Room', index: 3),
                      _buildCompactSidebarItem(icon: Icons.account_balance_wallet_rounded, title: 'Petty Cash', index: 4),
                      _buildCompactSidebarItem(icon: Icons.delete_sweep_rounded, title: 'Spoilage & Waste', index: 5),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _buildCompactSidebarLogoutItem(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedIndex == 0
                            ? 'Dashboard Overview'
                            : _selectedIndex == 1
                                ? 'Kitchen Stock Requests'
                                : _selectedIndex == 2
                                    ? 'Inventory Management'
                                    : _selectedIndex == 3
                                        ? 'Storage Rooms'
                                        : _selectedIndex == 4
                                            ? 'Petty Cash Expense'
                                            : 'Spoilage & Wastage Tracker',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIndex == 0)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF14332E), size: 20),
                          onPressed: _loadDashboardData,
                          tooltip: 'Refresh Data',
                        ),
                      _buildNotificationIcon(const Color(0xFF14332E)),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading && _selectedIndex == 0
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF14332E)))
                      : _getPages()[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: Drawer(
        backgroundColor: const Color(0xFF14332E),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFE6C374), size: 32),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pagsanjan Inventory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(_userName, style: const TextStyle(fontSize: 12, color: Color(0xFFC7D6D3))),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: [
                    _buildSidebarItem(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
                    _buildSidebarItem(icon: Icons.shopping_bag_rounded, title: 'Kitchen Requests', index: 1),
                    _buildSidebarItem(icon: Icons.inventory_2_rounded, title: 'Manage Inventory', index: 2),
                    _buildSidebarItem(icon: Icons.warehouse_rounded, title: 'Storage Room', index: 3),
                    _buildSidebarItem(icon: Icons.account_balance_wallet_rounded, title: 'Petty Cash', index: 4),
                    _buildSidebarItem(icon: Icons.delete_sweep_rounded, title: 'Spoilage & Waste', index: 5),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                  title: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: _signOut,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14332E),
        foregroundColor: Colors.white,
        title: Text(
          _selectedIndex == 0
              ? 'Dashboard'
              : _selectedIndex == 1
                  ? 'Kitchen Requests'
                  : _selectedIndex == 2
                      ? 'Inventory'
                      : _selectedIndex == 3
                          ? 'Storage'
                          : _selectedIndex == 4
                              ? 'Petty Cash'
                              : 'Spoilage & Waste',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          _buildNotificationIcon(Colors.white),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading && _selectedIndex == 0
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14332E)))
          : _getPages()[_selectedIndex],
    );
  }

  Widget _buildCompactSidebarItem({required IconData icon, required String title, required int index}) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E4A42) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.5), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFFD9A441) : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFD9A441) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD9A441),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSidebarLogoutItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _signOut,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 18),
                SizedBox(width: 10),
                Text('Logout', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem({required IconData icon, required String title, required int index}) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            _onItemTapped(index);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E4A42) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? const Color(0xFFD9A441) : Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFD9A441) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(Color iconColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getInventoryNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n['is_read']).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_rounded,
                color: iconColor,
                size: 20,
              ),
              onPressed: () => _showNotificationsDialog(notifications),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_rounded, color: Color(0xFF14332E)),
            SizedBox(width: 8),
            Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 480,
          child: notifications.isEmpty
              ? const Center(child: Text('No new activity notifications'))
              : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final date = DateTime.parse(n['created_at']).toLocal();
                    final timeStr = DateFormat('MMM d, h:mm a').format(date);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF14332E).withValues(alpha: 0.1),
                        child: Icon(_getIconForAction(n['action_type']), color: const Color(0xFF14332E), size: 18),
                      ),
                      title: Text(
                        _getNotificationTitle(n),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getNotificationSubtitle(n), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(timeStr, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
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

  void _showInvNotificationToast(Map<String, dynamic> n) {
    if (!mounted) return;
    final title = _getNotificationTitle(n);
    final subtitle = _getNotificationSubtitle(n);

    void openBellDialog() {
      _dismissInvTopToast();
      NotificationService.getInventoryNotificationsStream()
          .first
          .then((notifs) {
        if (mounted) _showNotificationsDialog(notifs);
      });
    }

    // FIXED at top: stays until Inventory Admin clicks 'VIEW'
    _showInvTopToast(
      duration: null,
      content: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openBellDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForAction(n['action_type']),
                    color: const Color(0xFF10B981),
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
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
      case 'stock_request':
        return Icons.inventory_2_rounded;
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'pos_order':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getNotificationTitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') return 'Stock Request from Kitchen';
    if (n['action_type'] == 'stock_alert') return 'Inventory Stock Alert';
    if (n['action_type'] == 'pos_order') return 'New POS Order';
    return 'Inventory Notification';
  }

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Kitchen Chef requested: ${n['event_type'] ?? 'Stock items'}';
    }
    if (n['action_type'] == 'stock_alert') {
      return n['event_type'] ?? 'Stock level is critical.';
    }
    return n['event_type'] ?? 'Inventory system update.';
  }
}

/// Animated Top Toast Notification Banner for Inventory
class _InvTopToastWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Duration? duration;

  const _InvTopToastWidget({
    required this.child,
    required this.onDismiss,
    this.duration,
  });

  @override
  State<_InvTopToastWidget> createState() => _InvTopToastWidgetState();
}

class _InvTopToastWidgetState extends State<_InvTopToastWidget>
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
