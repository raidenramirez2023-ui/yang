import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/staff/inventory_management.dart';

import 'package:yang_chow/pages/staff/inventory_room_page.dart';
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

  int _itemsPerPage = 15;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedWeek = 1;

  List<Map<String, dynamic>> _topRequestedItems = [];
  Map<String, Map<String, int>> _inventoryHealthByCategory = {};
  Map<String, Map<String, int>> _transactionsByDate = {};
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _criticalItems = [];



  RealtimeChannel? _inventorySubscription;
  late Stream<List<Map<String, dynamic>>> _allRequestsStream;

  int _getCurrentWeekOfMonth(DateTime date) {
    int day = date.day;
    if (day <= 7) return 1;
    if (day <= 14) return 2;
    if (day <= 21) return 3;
    return 4;
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
    NotificationService.startStockMonitoring();
  }

  void _setupRealtimeSubscription() {
    _inventorySubscription = _supabase
        .channel('public:inventory_dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory',
          callback: (payload) {
            if (mounted) {
              _loadDashboardData();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kitchen_requests',
          callback: (payload) {
            if (mounted) {
              _loadDashboardData();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    NotificationService.stopStockMonitoring();
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

        // Fetch Recent Activity
        final activityResponse = await _supabase
            .from('stock_transactions')
            .select()
            .order('created_at', ascending: false)
            .limit(5);

        // Calculate date range for filtering (4-week logic)
        final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        int startDay = (_selectedWeek - 1) * 7 + 1;
        int endDay = _selectedWeek * 7;
        
        // Week 4 covers from day 22 to the end of the month
        if (_selectedWeek == 4) {
          endDay = lastDayOfMonth;
        }
        
        // Ensure startDay doesn't exceed lastDayOfMonth (e.g. Feb 29-31)
        if (startDay > lastDayOfMonth) {
          startDay = lastDayOfMonth;
        }
        
        final startDate = DateTime(_selectedYear, _selectedMonth, startDay, 0, 0, 0).toIso8601String();
        final endDate = DateTime(_selectedYear, _selectedMonth, endDay, 23, 59, 59).toIso8601String();

        // Fetch Top Requested Items (from Approved kitchen requests) with filtering
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
        }
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

  }



  Future<void> _signOut() async {

    final bool? shouldLogout = await showDialog<bool>(

      context: context,

      builder: (BuildContext context) {

        return AlertDialog(

          title: Row(

            children: [

              const Icon(Icons.logout, color: AppTheme.primaryColor, size: 24),

              const SizedBox(width: 12),

              const Text('Confirm Logout'),

            ],

          ),

          content: const Text(

            'Are you sure you want to logout from the Inventory Management System?',

            style: TextStyle(fontSize: 16),

          ),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(12),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.of(context).pop(false),

              style: TextButton.styleFrom(

                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                ),

              ),

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: AppTheme.mediumGrey,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

            ElevatedButton(

              onPressed: () => Navigator.of(context).pop(true),

              style: ElevatedButton.styleFrom(

                backgroundColor: AppTheme.primaryColor,

                foregroundColor: AppTheme.white,

                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(8),

                ),

              ),

              child: const Text(

                'Logout',

                style: TextStyle(fontWeight: FontWeight.w600),

              ),

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

            SnackBar(

              content: Text('Error signing out: $e'),

              backgroundColor: AppTheme.errorRed,

            ),

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

    ];

  }



  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 20),
            
            _buildCriticalAlerts(),
            
            _buildDashboardToolbar(),
            const SizedBox(height: 28),
            
            _buildInventoryInsights(),
            const SizedBox(height: 28),
            
            _buildActivityFeed(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final now = DateTime.now();
    String greeting = 'Magandang Araw';
    if (now.hour < 12) greeting = 'Magandang Umaga';
    else if (now.hour < 18) greeting = 'Magandang Hapon';
    else greeting = 'Magandang Gabi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.inventory_2_rounded,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_userName!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
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
        final isNarrow = constraints.maxWidth < 800;
        
        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightGrey.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mediumGrey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildFlatStatsRow(isNarrow: true),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.lightGrey, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mediumGrey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildFlatActionsRow(isNarrow: true),
              ],
            ),
          );
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightGrey.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkGrey.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFlatStatsRow(isNarrow: false),
              _buildFlatActionsRow(isNarrow: false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlatStatsRow({required bool isNarrow}) {
    if (isNarrow) {
      return Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          _buildFlatStatItem('Total Items', _totalInventoryItems.toString(), AppTheme.primaryColor),
          _buildFlatStatItem('Low Stock', _lowStockItems.toString(), AppTheme.warningOrange),
          _buildFlatStatItem('Out of Stock', _outOfStockItems.toString(), AppTheme.errorRed),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlatStatItem('Total Items', _totalInventoryItems.toString(), AppTheme.primaryColor),
        _buildFlatDivider(),
        _buildFlatStatItem('Low Stock', _lowStockItems.toString(), AppTheme.warningOrange),
        _buildFlatDivider(),
        _buildFlatStatItem('Out of Stock', _outOfStockItems.toString(), AppTheme.errorRed),
      ],
    );
  }

  Widget _buildFlatStatItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.mediumGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: 1,
        height: 16,
        color: AppTheme.lightGrey,
      ),
    );
  }

  Widget _buildFlatActionsRow({required bool isNarrow}) {
    if (isNarrow) {
      return Row(
        children: [
          Expanded(child: _buildFlatActionButton('Requests', Icons.shopping_cart_outlined, AppTheme.primaryColor, () => _onItemTapped(1))),
          const SizedBox(width: 8),
          Expanded(child: _buildFlatActionButton('Manage', Icons.edit_note_outlined, AppTheme.infoBlue, () => _onItemTapped(2))),
          const SizedBox(width: 8),
          Expanded(child: _buildFlatActionButton('Storage', Icons.warehouse_outlined, AppTheme.warningOrange, () => _onItemTapped(3))),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlatActionButton('Kitchen Requests', Icons.shopping_cart_outlined, AppTheme.primaryColor, () => _onItemTapped(1)),
        const SizedBox(width: 8),
        _buildFlatActionButton('Manage Inventory', Icons.edit_note_outlined, AppTheme.infoBlue, () => _onItemTapped(2)),
        const SizedBox(width: 8),
        _buildFlatActionButton('Storage Room', Icons.warehouse_outlined, AppTheme.warningOrange, () => _onItemTapped(3)),
      ],
    );
  }

  Widget _buildFlatActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.darkGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.mediumGrey),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
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
        const Text(
          'Inventory Insights',
          style: AppTheme.sectionHeaderStyle,
        ),
        const SizedBox(height: 16),
        if (isMobile) ...[
          _buildInventoryHealthChart(),
          const SizedBox(height: 16),
          _buildTopRequestedItemsChart(),
        ] else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildInventoryHealthChart()),
                const SizedBox(width: 16),
                Expanded(child: _buildTopRequestedItemsChart()),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildInventoryHealthChart() {
    double maxY = 0;
    for (var value in _inventoryHealthByCategory.values) {
      final total = value['good']! + value['low']! + value['out']!;
      if (total > maxY) maxY = total.toDouble();
    }
    // Add some padding to maxY
    maxY = maxY + (maxY * 0.2).ceil();
    if (maxY < 5) maxY = 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Inventory Health by Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Current stock status of items per category.',
            style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
          ),
          const SizedBox(height: 24),
          if (_inventoryHealthByCategory.isEmpty)
            _buildChartEmptyState(
              Icons.bar_chart_rounded,
              'No Category Data',
              'Inventory health details per category will display here.',
            )
          else
            SizedBox(
              height: 330,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = _inventoryHealthByCategory.keys.toList()[group.x.toInt()];
                        final values = _inventoryHealthByCategory[category]!;
                        return BarTooltipItem(
                          '$category\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: 'Good: ${values['good']}\n', style: const TextStyle(color: AppTheme.successGreen, fontSize: 12)),
                            TextSpan(text: 'Low: ${values['low']}\n', style: const TextStyle(color: AppTheme.warningOrange, fontSize: 12)),
                            TextSpan(text: 'Out: ${values['out']}', style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
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
                        reservedSize: 50,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final categoryNames = _inventoryHealthByCategory.keys.toList();
                          final index = value.toInt();
                          if (index >= 0 && index < categoryNames.length) {
                            String text = categoryNames[index];
                            if (text.length > 15) text = '${text.substring(0, 13)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 12,
                              child: Transform.rotate(
                                angle: -0.25,
                                child: Text(
                                  text,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                                ),
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
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.lightGrey, strokeWidth: 1),
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
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          rodStackItems: [
                            BarChartRodStackItem(0, good, AppTheme.successGreen),
                            BarChartRodStackItem(good, good + low, AppTheme.warningOrange),
                            BarChartRodStackItem(good + low, total, AppTheme.errorRed),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppTheme.successGreen, 'Good'),
              const SizedBox(width: 16),
              _buildLegendItem(AppTheme.warningOrange, 'Low'),
              const SizedBox(width: 16),
              _buildLegendItem(AppTheme.errorRed, 'Out'),
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
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, color: AppTheme.infoBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Top 5 Requested Items',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFilterDropdown<int>(
                    value: _selectedYear,
                    items: List.generate(2032 - DateTime.now().year, (index) => DateTime.now().year + index),
                    label: 'Year',
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedYear = val);
                        _loadDashboardData();
                      }
                    },
                  ),
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
                    itemBuilder: (val) => 'Week $val',
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
          const SizedBox(height: 8),
          const Text(
            'Fast-moving ingredients for the selected period.',
            style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
          ),
          const SizedBox(height: 24),
          if (_topRequestedItems.isEmpty)
            _buildChartEmptyState(
              Icons.trending_up_outlined,
              'No Requests Found',
              'Top requested kitchen items for this period will appear here.',
            )
          else
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxX,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_topRequestedItems[groupIndex]['name']}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: 'Total: ${_topRequestedItems[groupIndex]['value']}',
                              style: const TextStyle(color: AppTheme.infoBlue, fontSize: 12, fontWeight: FontWeight.bold),
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
                        reservedSize: 50,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _topRequestedItems.length) {
                            String name = _topRequestedItems[index]['name'];
                            if (name.length > 15) name = '${name.substring(0, 13)}…';
                            return SideTitleWidget(
                              meta: meta,
                              space: 12,
                              child: Transform.rotate(
                                angle: -0.25,
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Quantity', style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.lightGrey, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _topRequestedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final val = (entry.value['value'] as num).toDouble();
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          color: AppTheme.infoBlue,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
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
    required ValueChanged<T?> onChanged,
    String Function(T)? itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mediumGrey),
          ),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.primaryColor),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
            items: items.map((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemBuilder != null ? itemBuilder(item) : item.toString()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCriticalAlerts() {
    if (_criticalItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Critical Stock Alerts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
              ),
            ),
            const Spacer(),
            if (_criticalItems.length > 5)
              TextButton(
                onPressed: _showAllCriticalItemsModal,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View All', style: TextStyle(fontSize: 12, color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
              ),
            if (_criticalItems.length > 5) const SizedBox(width: 8),
            Text(
              '${_criticalItems.length} items',
              style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _criticalItems.length,
            itemBuilder: (context, index) {
              final item = _criticalItems[index];
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['name'] ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qty == 0 ? 'OUT OF STOCK' : 'Only $qty left',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showAllCriticalItemsModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
              SizedBox(width: 8),
              Text('Critical Stock Alerts', style: TextStyle(color: AppTheme.errorRed)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _criticalItems.length,
              itemBuilder: (context, index) {
                final item = _criticalItems[index];
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Category: ${item['category'] ?? 'Other'}', style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      qty == 0 ? 'OUT OF STOCK' : '$qty left',
                      style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: AppTheme.sectionHeaderStyle,
            ),
            if (_recentActivity.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_recentActivity.length} entries',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppTheme.cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: _recentActivity.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.07),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 32,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Recent Activity',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Stock transactions will appear here.',
                          style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  itemBuilder: (context, index) {
                    final act = _recentActivity[index];
                    final type = act['transaction_type']?.toString() ?? 'unknown';
                    final date = DateTime.parse(act['created_at']?.toString() ?? DateTime.now().toIso8601String()).toLocal();
                    final isIncoming = type == 'incoming';
                    final accentColor = isIncoming ? AppTheme.successGreen : AppTheme.errorRed;
                    final iconColor = isIncoming ? AppTheme.successGreen : AppTheme.primaryColor;
                    final isEven = index.isEven;

                    return Container(
                      color: isEven ? Colors.transparent : AppTheme.backgroundColor.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: iconColor,
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppTheme.darkGrey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  act['purpose'] ?? 'Stock update',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${isIncoming ? '+' : '-'}${act['quantity']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('h:mm a').format(date),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.mediumGrey,
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





  Widget _buildRequestCard(Map<String, dynamic> request) {

    final status = request['status']?.toString() ?? 'Pending';

    final priority = request['priority']?.toString() ?? 'Normal';

    final itemName = request['item_name']?.toString() ?? 'Unknown';

    final quantity = request['quantity_needed']?.toString() ?? '0';

    final unit = request['unit']?.toString() ?? 'pcs';

    final requestedBy = request['requested_by']?.toString() ?? 'Unknown';

    final createdAt = request['created_at']?.toString();

    

    Color statusColor;

    IconData statusIcon;

    

    switch (status) {

      case 'Approved':

        statusColor = AppTheme.successGreen;

        statusIcon = Icons.check_circle;

        break;

      case 'Rejected':

        statusColor = AppTheme.errorRed;

        statusIcon = Icons.cancel;

        break;

      default:

        statusColor = AppTheme.warningOrange;

        statusIcon = Icons.pending;

    }

    

    Color priorityColor;

    switch (priority) {

      case 'Urgent':

        priorityColor = AppTheme.errorRed;

        break;

      case 'High':

        priorityColor = AppTheme.warningOrange;

        break;

      case 'Low':

        priorityColor = AppTheme.infoBlue;

        break;

      default:

        priorityColor = AppTheme.primaryColor;

    }

    

    return Container(

      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: statusColor.withOpacity(0.3)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(statusIcon, color: statusColor, size: 20),

              const SizedBox(width: 8),

              Expanded(

                child: Text(

                  itemName,

                  style: const TextStyle(

                    fontWeight: FontWeight.bold,

                    fontSize: 14,

                  ),

                ),

              ),

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                decoration: BoxDecoration(

                  color: statusColor.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: Text(

                  status,

                  style: TextStyle(

                    color: statusColor,

                    fontSize: 12,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 8),

          Row(

            children: [

              Text(

                '$quantity $unit',

                style: const TextStyle(

                  fontSize: 13,

                  color: AppTheme.darkGrey,

                ),

              ),

              const SizedBox(width: 16),

              Text(

                'Priority: $priority',

                style: TextStyle(

                  fontSize: 12,

                  color: priorityColor,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ],

          ),

          const SizedBox(height: 4),

          Text(

            'Requested by: $requestedBy',

            style: const TextStyle(

              fontSize: 11,

              color: AppTheme.mediumGrey,

            ),

          ),

          if (createdAt != null) ...[

            const SizedBox(height: 4),

            Text(

              'Time: ${DateTime.parse(createdAt).toString().substring(0, 16)}',

              style: const TextStyle(

                fontSize: 11,

                color: AppTheme.mediumGrey,

              ),

            ),

          ],

          if (status == 'Pending') ...[

            const SizedBox(height: 12),

            Row(

              children: [

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _handleRequestAction(request['id'], 'Approved'),
                    style: ElevatedButton.styleFrom(

                      backgroundColor: AppTheme.successGreen,

                      foregroundColor: Colors.white,

                      minimumSize: const Size(0, 32),

                    ),

                    icon: const Icon(Icons.check, size: 16),

                    label: const Text('Approve', style: TextStyle(fontSize: 12)),

                  ),

                ),

                const SizedBox(width: 8),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _handleRequestAction(request['id'], 'Rejected'),
                    style: OutlinedButton.styleFrom(

                      foregroundColor: AppTheme.errorRed,

                      minimumSize: const Size(0, 32),

                      side: const BorderSide(color: AppTheme.errorRed),

                    ),

                    icon: const Icon(Icons.close, size: 16),

                    label: const Text('Reject', style: TextStyle(fontSize: 12)),

                  ),

                ),

              ],

            ),

          ],

        ],

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

        // Check stock availability before approving
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
            return; // Don't proceed with approval if quantity is 0
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
              // Sufficient stock - proceed with approval
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
              // Insufficient stock - show warning and keep request pending
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot approve: Insufficient stock. Only $currentQuantity available, $quantityNeeded needed.'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
              return; // Don't proceed with approval
            }
          } else {
            // Item not found in inventory
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot approve: Item not found in inventory.'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            return; // Don't proceed with approval
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

  Future<void> _approveRequestCore(Map<String, dynamic> request) async {
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
        
        // Safety: Only transfer what is actually available in main inventory
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

          'created_at': DateTime.now().toIso8601String(),

        });



        await _supabase
            .from('kitchen_requests')
            .update({'status': 'Approved'})
            .eq('id', request['id']);

        // Notify Kitchen
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



  Future<void> _approveAllRequests() async {

    setState(() => _isLoading = true);

    try {

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

        return;

      }



      int approvedCount = 0;

      int outOfStockCount = 0;



      for (var request in pendingRequests) {

        final itemName = request['item_name']?.toString();

        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;



        if (itemName != null) {
          if (quantityNeeded == 0) {
            // Count zero quantity requests as out of stock
            outOfStockCount++;
            continue;
          }

          // Check stock availability in pagsanjaninv inventory

          final inventoryItems = await _supabase

              .from('inventory')

              .select('id, quantity')

              .ilike('name', '%$itemName%')

              .limit(1);



          if (inventoryItems.isNotEmpty) {

            final inventoryItem = inventoryItems.first;

            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;



            // Only approve if there's sufficient stock

            if (currentQuantity >= quantityNeeded) {

              await _approveRequestCore(request);

              approvedCount++;

            } else {

              // Keep request in pending state if out of stock

              outOfStockCount++;

            }

          } else {

            // Keep request in pending state if item not found in inventory

            outOfStockCount++;

          }

        }

      }



      if (mounted) {

        String message;

        Color backgroundColor;



        if (approvedCount > 0 && outOfStockCount > 0) {

          message = 'Approved $approvedCount requests successfully! $outOfStockCount requests remain pending due to insufficient stock.';

          backgroundColor = AppTheme.warningOrange;

        } else if (approvedCount > 0) {

          message = 'Approved $approvedCount requests successfully!';

          backgroundColor = AppTheme.successGreen;

        } else {

          message = 'No requests approved. All $outOfStockCount requests remain pending due to insufficient stock.';

          backgroundColor = AppTheme.errorRed;

        }



        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(message),

            backgroundColor: backgroundColor,

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

      // Reject all pending requests
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

      backgroundColor: Colors.transparent,

      body: Row(

        children: [

          Material(
            color: Colors.transparent,
            child: Container(
              width: 200,

            decoration: BoxDecoration(

              color: AppTheme.primaryColor,

              boxShadow: [

                BoxShadow(

                  color: AppTheme.darkGrey.withOpacity(0.1),

                  blurRadius: 4,

                  offset: const Offset(2, 0),

                ),

              ],

            ),

            child: Column(

              children: [

                // Compact Header

                Container(

                  padding: const EdgeInsets.all(16),

                  child: Column(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(

                          color: AppTheme.white.withOpacity(0.2),

                          borderRadius: BorderRadius.circular(8),

                        ),

                        child: const Icon(

                          Icons.inventory_2,

                          color: AppTheme.white,

                          size: 24,

                        ),

                      ),

                      const SizedBox(height: 8),

                      const Text(

                        'Inventory',

                        style: TextStyle(

                          fontSize: 14,

                          fontWeight: FontWeight.w700,

                          color: AppTheme.white,

                        ),

                      ),

                      Text(

                        _userName,

                        style: const TextStyle(

                          fontSize: 12,

                          color: AppTheme.white,

                          fontWeight: FontWeight.w500,

                        ),

                      ),

                    ],

                  ),

                ),

                

                Divider(color: AppTheme.white.withOpacity(0.2), height: 1),

                

                // Navigation Items

                Expanded(

                  child: ListView(

                    padding: const EdgeInsets.symmetric(vertical: 8),

                    children: [

                      _buildCompactSidebarItem(

                        icon: Icons.dashboard,

                        title: 'Dashboard',

                        index: 0,

                      ),

                      _buildCompactSidebarItem(

                        icon: Icons.shopping_cart,

                        title: 'Kitchen Requests',

                        index: 1,

                      ),

                      _buildCompactSidebarItem(

                        icon: Icons.inventory,

                        title: 'Inventory',

                        index: 2,

                      ),

                      _buildCompactSidebarItem(

                        icon: Icons.warehouse,

                        title: 'Storage Room',

                        index: 3,

                      ),

                      _buildCompactSidebarLogoutItem(),

                      
                    ],

                  ),

                ),

                

              ],

            ),

          ),
        ),

          

          // Main Content

          Expanded(

            child: Column(

              children: [

                // Top Bar

                Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: AppTheme.white,

                    boxShadow: [

                      BoxShadow(

                        color: AppTheme.darkGrey.withOpacity(0.1),

                        blurRadius: 2,

                        offset: const Offset(0, 1),

                      ),

                    ],

                  ),

                  child: Row(

                    children: [

                      Icon(

                        _selectedIndex == 0 ? Icons.dashboard :

                        _selectedIndex == 1 ? Icons.shopping_cart :

                        _selectedIndex == 2 ? Icons.inventory :

                        Icons.warehouse,

                        color: AppTheme.primaryColor,

                        size: 20,

                      ),

                      const SizedBox(width: 8),

                      Text(

                        _selectedIndex == 0 ? 'Dashboard' :

                        _selectedIndex == 1 ? 'Kitchen Stock Requests' :

                        _selectedIndex == 2 ? 'Manage Inventory' :

                        'Storage Room',

                        style: const TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.w600,

                          color: AppTheme.darkGrey,

                        ),

                      ),

                      const Spacer(),

                      if (_selectedIndex == 0)

                        IconButton(

                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),

                          onPressed: _loadDashboardData,

                        ),

                      _buildNotificationIcon(AppTheme.primaryColor),

                    ],

                  ),

                ),

                

                // Content

                Expanded(

                  child: _isLoading && _selectedIndex == 0

                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: Row(
          children: [
            const Icon(Icons.dashboard_rounded),
            const SizedBox(width: 8),
            const Text('Inventory Dashboard'),
          ],
        ),
        actions: [
          _buildNotificationIcon(Colors.white),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryDark,
              ],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: AppTheme.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Inventory Staff',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: AppTheme.white, height: 1),
              
              // Navigation Items
              ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shrinkWrap: true,
                children: [
                  _buildSidebarItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    index: 0,
                  ),
                  _buildSidebarItem(
                    icon: Icons.shopping_cart,
                    title: 'Kitchen Requests',
                    index: 1,
                  ),
                  _buildSidebarItem(
                    icon: Icons.inventory,
                    title: 'Manage Inventory',
                    index: 2,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warehouse,
                    title: 'Storage Room',
                    index: 3,
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Logout Button
              Container(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.white),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _signOut,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading && _selectedIndex == 0
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _getPages()[_selectedIndex],
    );
  }



  Widget _buildCompactSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppTheme.white.withOpacity(0.08),
          splashColor: AppTheme.white.withOpacity(0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.white.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppTheme.white.withOpacity(0.25), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.65),
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _signOut,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.red.withOpacity(0.15),
          splashColor: Colors.red.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppTheme.white.withOpacity(0.65),
                  size: 19,
                ),
                const SizedBox(width: 10),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppTheme.white.withOpacity(0.08),
          splashColor: AppTheme.white.withOpacity(0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.white.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppTheme.white.withOpacity(0.25), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.65),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.white,
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



  Widget _buildKitchenRequestsPage() {

    return RefreshIndicator(

      onRefresh: _loadDashboardData,

      color: AppTheme.primaryColor,

      child: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Kitchen Stock Requests',

                      style: TextStyle(

                        fontSize: 24,

                        fontWeight: FontWeight.bold,

                        color: AppTheme.darkGrey,

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      'Manage stock requests from the kitchen team',

                      style: TextStyle(

                        fontSize: 14,

                        color: AppTheme.mediumGrey,

                      ),

                    ),

                  ],

                ),

                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _approveAllRequests,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _rejectAllRequests,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject All', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),

              ],

            ),

            const SizedBox(height: 24),

            // Unified StreamBuilder for both Counter and List
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _allRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                  );
                }

                final requests = snapshot.data ?? [];
                
                // Sort requests: Pending first, then Approved, then Rejected
                requests.sort((a, b) {
                  final statusA = a['status']?.toString() ?? 'Pending';
                  final statusB = b['status']?.toString() ?? 'Pending';
                  
                  // Priority order: Pending (1), Approved (2), Rejected (3)
                  final priorityA = statusA == 'Pending' ? 1 : statusA == 'Approved' ? 2 : 3;
                  final priorityB = statusB == 'Pending' ? 1 : statusB == 'Approved' ? 2 : 3;
                  
                  if (priorityA != priorityB) {
                    return priorityA.compareTo(priorityB);
                  }
                  
                  // Within same status, sort by created_at descending (newest first)
                  final createdAtA = DateTime.parse(a['created_at']?.toString() ?? DateTime.now().toIso8601String());
                  final createdAtB = DateTime.parse(b['created_at']?.toString() ?? DateTime.now().toIso8601String());
                  return createdAtB.compareTo(createdAtA);
                });

                final pendingCount = requests.where((r) => r['status'] == 'Pending').length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Request Counter
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pending_actions, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Total Pending Requests: $pendingCount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Spacer(),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warningOrange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // All Requests Container
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.lightGrey),
                      ),
                      child: () {
                        if (requests.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 60, color: AppTheme.mediumGrey),
                                const SizedBox(height: 16),
                                Text(
                                  'No stock requests',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.mediumGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kitchen team hasn\'t requested any items yet',
                                  style: TextStyle(color: AppTheme.mediumGrey),
                                ),
                              ],
                            ),
                          );
                        }

                        final totalPages = (requests.length / _itemsPerPage).ceil();
                        final startIndex = (_currentPage - 1) * _itemsPerPage;
                        final endIndex = startIndex + _itemsPerPage;
                        final paginatedRequests = requests.sublist(
                          startIndex,
                          endIndex > requests.length ? requests.length : endIndex,
                        );

                        return Column(
                          children: [
                            ...paginatedRequests.map((request) => _buildRequestCard(request)).toList(),
                            
                            if (totalPages > 1) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: _currentPage > 1
                                          ? () {
                                              setState(() {
                                                _currentPage--;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.chevron_left),
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 50,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppTheme.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.primaryColor),
                                      ),
                                      child: TextField(
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.darkGrey,
                                        ),
                                        controller: TextEditingController(text: _currentPage.toString()),
                                        onSubmitted: (value) {
                                          final page = int.tryParse(value);
                                          if (page != null && page >= 1 && page <= totalPages) {
                                            setState(() {
                                              _currentPage = page;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'of $totalPages',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      onPressed: _currentPage < totalPages
                                          ? () {
                                              setState(() {
                                                _currentPage++;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.chevron_right),
                                      color: AppTheme.primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      }(),
                    ),
                  ],
                );
              },
            ),

          ],

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
                unreadCount > 0 ? Icons.notifications_active : Icons.notifications,
                color: iconColor,
              ),
              onPressed: () => _showNotificationsDialog(notifications),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
        title: const Text('Inventory Notifications'),
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
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          _getIconForAction(n['action_type']),
                          color: AppTheme.primaryColor,
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
                          Text(_getNotificationSubtitle(n)),
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






