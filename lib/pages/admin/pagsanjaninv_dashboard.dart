import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/staff/inventory_management.dart';
import 'package:yang_chow/pages/staff/inventory_room_page.dart';
import 'package:yang_chow/pages/staff/petty_cash_expense_page.dart';
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
  bool _hasShownCriticalModal = false;

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
          .select('quantity, name, category');

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

          if (!_hasShownCriticalModal && critical.isNotEmpty) {
            _hasShownCriticalModal = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCriticalStockPopup();
            });
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
      const InventoryRoomPage(),
      const PettyCashExpensePage(),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C374).withValues(alpha: 0.2),
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
                  const Spacer(),
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
                          DateFormat('MMMM dd, yyyy').format(DateTime.now()),
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
      return Row(
        children: items.map((e) => Expanded(child: e)).toList(),
      );
    }

    return Row(
      children: items.map((e) => Expanded(child: e)).toList(),
    );
  }

  Widget _buildStatTile(String label, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
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
      return Row(
        children: actions.map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: e))).toList(),
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
              const Text(
                'Critical Stock Attention Required',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF991B1B),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAllCriticalItemsModal,
                icon: const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFDC2626)),
                label: Text(
                  'View All (${_criticalItems.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        const Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: Color(0xFF14332E), size: 20),
            SizedBox(width: 8),
            Text(
              'Inventory Analytics & Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
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
    for (var value in _inventoryHealthByCategory.values) {
      final total = value['good']! + value['low']! + value['out']!;
      if (total > maxY) maxY = total.toDouble();
    }
    maxY = maxY + (maxY * 0.2).ceil();
    if (maxY < 5) maxY = 5;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Stock Health',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Item status distribution across departments',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_inventoryHealthByCategory.isEmpty)
            _buildChartEmptyState(Icons.bar_chart_rounded, 'No Category Data', 'Stock metrics will display once inventory is added.')
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = _inventoryHealthByCategory.keys.toList()[group.x.toInt()];
                        final values = _inventoryHealthByCategory[category]!;
                        return BarTooltipItem(
                          '$category\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: 'Good: ${values['good']}\n', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                            TextSpan(text: 'Low: ${values['low']}\n', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                            TextSpan(text: 'Out: ${values['out']}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
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
                            if (text.length > 10) text = '${text.substring(0, 8)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
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
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Good (10+)'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFF59E0B), 'Low (1-9)'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFEF4444), 'Out (0)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRequestedItemsChart() {
    double maxX = 0;
    for (var item in _topRequestedItems) {
      final val = (item['value'] as num).toDouble();
      if (val > maxX) maxX = val;
    }
    maxX = maxX + (maxX * 0.2).ceil();
    if (maxX < 5) maxX = 5;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Top Kitchen Requests',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
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
          const SizedBox(height: 20),
          if (_topRequestedItems.isEmpty)
            _buildChartEmptyState(Icons.trending_up_outlined, 'No Requests Found', 'Top kitchen items for this timeframe will appear here.')
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_topRequestedItems[groupIndex]['name']}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: 'Total: ${_topRequestedItems[groupIndex]['value']}',
                              style: const TextStyle(color: Color(0xFFE6C374), fontSize: 12, fontWeight: FontWeight.bold),
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
                            if (name.length > 10) name = '${name.substring(0, 8)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
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
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14332E), Color(0xFF28564D)],
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
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Highest demand ingredients dispatched to kitchen',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
        ),
      ],
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
    final outOfStockItems = _criticalItems.where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) == 0).toList();
    final lowStockItems = _criticalItems.where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) > 0).toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Critical Stock Alerts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${_criticalItems.length} item${_criticalItems.length == 1 ? '' : 's'} require immediate replenishment',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      _buildSummaryChip('Out of Stock', outOfStockItems.length.toString(), const Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      _buildSummaryChip('Low Stock', lowStockItems.length.toString(), const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    children: [
                      if (outOfStockItems.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 8, bottom: 8),
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEF4444), letterSpacing: 0.6),
                          ),
                        ),
                        ...outOfStockItems.map((item) => _buildCriticalItemTile(item, isOutOfStock: true)),
                      ],
                      if (lowStockItems.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 14, bottom: 8),
                          child: Text(
                            'LOW STOCK',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B), letterSpacing: 0.6),
                          ),
                        ),
                        ...lowStockItems.map((item) => _buildCriticalItemTile(item, isOutOfStock: false)),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          _onItemTapped(2);
                        },
                        child: const Text('Go to Inventory', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: const Color(0xFFE6C374),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildSummaryChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildCriticalItemTile(Map<String, dynamic> item, {required bool isOutOfStock}) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final statusColor = isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(isOutOfStock ? Icons.cancel_rounded : Icons.warning_rounded, color: statusColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                Text(
                  item['category'] ?? 'General',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOutOfStock ? 'OUT OF STOCK' : '$qty left',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
            ),
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
              padding: const EdgeInsets.all(20),
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
              child: Row(
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
        await _supabase
            .from('kitchen_requests')
            .update({'status': newStatus})
            .eq('id', requestId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request rejected.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
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
          .select('id, quantity')
          .ilike('name', '%$itemName%')
          .limit(1);

      if (inventoryItems.isNotEmpty) {
        final inventoryItem = inventoryItems.first;
        final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;

        final transferQty = quantityNeeded > currentQuantity ? currentQuantity : quantityNeeded;
        final newQuantity = currentQuantity - transferQty;

        await _supabase
            .from('inventory')
            .update({'quantity': newQuantity})
            .eq('id', inventoryItem['id']);

        final fullInventoryItem = await _supabase
            .from('inventory')
            .select('name, category, unit')
            .eq('id', inventoryItem['id'])
            .single();

        final kitchenItem = await _supabase
            .from('kitchen_inventory')
            .select()
            .eq('name', fullInventoryItem['name'])
            .maybeSingle();

        if (kitchenItem != null) {
          final currentKitchenQty = (kitchenItem['quantity'] as num?)?.toInt() ?? 0;
          await _supabase
              .from('kitchen_inventory')
              .update({'quantity': currentKitchenQty + transferQty})
              .eq('id', kitchenItem['id']);
        } else {
          await _supabase.from('kitchen_inventory').insert({
            'name': fullInventoryItem['name'],
            'category': fullInventoryItem['category'],
            'unit': fullInventoryItem['unit'],
            'quantity': transferQty,
          });
        }

        await _supabase.from('stock_transactions').insert({
          'item_name': itemName,
          'quantity': transferQty,
          'transaction_type': 'outgoing',
          'purpose': 'Kitchen request approved (Amount served: $transferQty)',
          'requested_by': request['requested_by'],
          'processed_by': _supabase.auth.currentUser?.email,
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

      final pendingRequests = await _supabase
          .from('kitchen_requests')
          .select()
          .eq('status', 'Pending');

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

      int approvedCount = 0;
      int outOfStockCount = 0;

      for (var request in pendingRequests) {
        final itemName = request['item_name']?.toString();
        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

        if (itemName != null && quantityNeeded > 0) {
          final inventoryItems = await _supabase
              .from('inventory')
              .select('id, quantity')
              .ilike('name', '%$itemName%')
              .limit(1);

          if (inventoryItems.isNotEmpty) {
            final inventoryItem = inventoryItems.first;
            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;

            if (currentQuantity >= quantityNeeded) {
              await _approveRequestCore(request, skipNotification: true);
              approvedCount++;
            } else {
              outOfStockCount++;
            }
          } else {
            outOfStockCount++;
          }
        }
      }

      if (approvedCount > 0) {
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
        String message;
        Color backgroundColor;

        if (approvedCount > 0 && outOfStockCount > 0) {
          message = 'Approved $approvedCount requests! $outOfStockCount remain pending (low stock).';
          backgroundColor = AppTheme.warningOrange;
        } else if (approvedCount > 0) {
          message = 'Approved $approvedCount requests successfully!';
          backgroundColor = AppTheme.successGreen;
        } else {
          message = 'No requests approved. All $outOfStockCount requests remain pending (insufficient stock).';
          backgroundColor = AppTheme.errorRed;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: backgroundColor),
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

      if (pendingRequests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending requests to reject.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      for (var request in pendingRequests) {
        await _supabase
            .from('kitchen_requests')
            .update({'status': 'Rejected'})
            .eq('id', request['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${pendingRequests.length} requests successfully!'),
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
                                        : 'Petty Cash Expense',
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
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF14332E)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFE6C374), size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pagsanjan Inventory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(_userName, style: const TextStyle(fontSize: 12, color: Color(0xFFC7D6D3))),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shrinkWrap: true,
                children: [
                  _buildSidebarItem(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
                  _buildSidebarItem(icon: Icons.shopping_bag_rounded, title: 'Kitchen Requests', index: 1),
                  _buildSidebarItem(icon: Icons.inventory_2_rounded, title: 'Manage Inventory', index: 2),
                  _buildSidebarItem(icon: Icons.warehouse_rounded, title: 'Storage Room', index: 3),
                  _buildSidebarItem(icon: Icons.account_balance_wallet_rounded, title: 'Petty Cash', index: 4),
                ],
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.white70),
                title: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: _signOut,
              ),
              const SizedBox(height: 12),
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
                          : 'Petty Cash',
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
    if (n['action_type'] == 'stock_request') return 'Stock Request';
    if (n['action_type'] == 'stock_alert') return 'Stock Alert';
    if (n['action_type'] == 'pos_order') return 'New Order';
    return 'Inventory Notification';
  }

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Kitchen requested: ${n['event_type'] ?? ''}';
    }
    if (n['action_type'] == 'stock_alert') {
      return n['event_type'] ?? 'Stock Alert';
    }
    return n['event_type'] ?? 'System Update';
  }
}
