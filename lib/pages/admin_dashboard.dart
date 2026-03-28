import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final _supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _ordersStream;
  late Stream<List<Map<String, dynamic>>> _inventoryStream;
  late Stream<List<Map<String, dynamic>>> _reservationsStream;

  // ── KPI data (now derived from streams) ──────────────────────────────────
  double _dailyRevenue = 0.0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _reservations = 0;
  List<double> _weeklyRevenue = List.filled(7, 0.0);
  int _pendingOrders = 0;
  int _preparingOrders = 0;
  int _readyOrders = 0;
  int _outOfStock = 0;
  int _lowStock = 0;
  double _revenueGrowth = 0.0;
  double _orderGrowth = 0.0;
  double _customerGrowth = 0.0;

  // ── Recent activity (now derived from streams) ───────────────────────────
  List<_ActivityItem> _recentActivity = [];
  DateTime? _lastUpdated;
  int _previousOrderCount = 0;
  bool _showNewOrderNotification = false;
  String _newOrderAmount = '';

  @override
  void initState() {
    super.initState();
    
    // Enhanced real-time streams with immediate updates
    _ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((events) => events.map((order) {
          // Ensure all order data is properly loaded
          return {
            ...order,
            'total_amount': order['total_amount'] ?? 0.0,
            'created_at': order['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'customer_name': order['customer_name'] ?? 'Guest',
            'transaction_id': order['transaction_id'] ?? order['id'],
          };
        }).toList());
        
    _inventoryStream = _supabase.from('inventory').stream(primaryKey: ['id']);
    _reservationsStream = _supabase.from('reservations').stream(primaryKey: ['id']).order('created_at', ascending: false);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _processData(
    List<Map<String, dynamic>> allOrders, 
    List<Map<String, dynamic>> allInventory,
    List<Map<String, dynamic>> allReservations,
  ) {
    // Check for new orders (real-time detection)
    final currentOrderCount = allOrders.length;
    if (_previousOrderCount > 0 && currentOrderCount > _previousOrderCount) {
      // New order detected!
      final newOrders = allOrders.take(currentOrderCount - _previousOrderCount).toList();
      for (var newOrder in newOrders) {
        final amount = (newOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
        _newOrderAmount = '₱${amount.toStringAsFixed(2)}';
        _showNewOrderNotification = true;
        
        // Auto-hide notification after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showNewOrderNotification = false;
            });
          }
        });
      }
    }
    _previousOrderCount = currentOrderCount;

    // KPI Data
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Get ALL orders for today (comprehensive daily revenue)
    final todayOrders = allOrders.where((o) {
      final createdAt = o['created_at']?.toString() ?? '';
      return createdAt.startsWith(todayStr);
    }).toList();
    
    // Calculate total daily revenue from ALL orders today (preserve decimal values)
    _dailyRevenue = todayOrders.fold(0.0, (sum, o) {
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
    _totalOrders = todayOrders.length;
    
    Set<String> uniqueCustomers = {};
    for (var o in todayOrders) {
      uniqueCustomers.add(o['customer_name'] ?? 'Guest');
    }
    _totalCustomers = uniqueCustomers.length;
    
    // Reservations (Events) - Only count ongoing confirmed reservations
    final todayReservations = allReservations.where((r) {
      final isToday = (r['event_date']?.toString() ?? '') == todayStr;
      final isConfirmed = (r['status']?.toString() ?? '').toLowerCase() == 'confirmed';
      if (!isToday || !isConfirmed) return false;
      
      // Auto-expiration logic: check if the event is currently active
      return _isReservationOngoing(r);
    }).toList();
    _reservations = todayReservations.length;

    // Weekly Revenue Calculation
    _weeklyRevenue = _processChartData(allOrders);

    // Kitchen Status Counts (Real-time from today's orders)
    _pendingOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? 'Pending') == 'Pending').length;
    _preparingOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? '') == 'Preparing').length;
    _readyOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? '') == 'Ready').length;
    
    // Growth Calculations (vs Yesterday) - Compare total daily revenue
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    
    // Get ALL orders from yesterday for accurate comparison
    final yesterdayOrders = allOrders.where((o) {
      final createdAt = o['created_at']?.toString() ?? '';
      return createdAt.startsWith(yesterdayStr);
    }).toList();
    
    final yesterdayRevenue = yesterdayOrders.fold(0.0, (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0.0));
    final yesterdayOrdersCount = yesterdayOrders.length;
    
    if (yesterdayRevenue > 0) {
      _revenueGrowth = ((_dailyRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
    } else {
      _revenueGrowth = _dailyRevenue > 0 ? 100.0 : 0.0;
    }

    if (yesterdayOrdersCount > 0) {
      _orderGrowth = ((_totalOrders - yesterdayOrdersCount) / yesterdayOrdersCount) * 100;
    } else {
      _orderGrowth = _totalOrders > 0 ? 100.0 : 0.0;
    }
    
    Set<String> yesterdayCustomers = {};
    for (var o in yesterdayOrders) {
      yesterdayCustomers.add(o['customer_name'] ?? 'Guest');
    }
    if (yesterdayCustomers.isNotEmpty) {
      _customerGrowth = ((_totalCustomers - yesterdayCustomers.length) / yesterdayCustomers.length) * 100;
    } else {
      _customerGrowth = _totalCustomers > 0 ? 100.0 : 0.0;
    }

    // Inventory Alerts (Real-time)
    _outOfStock = allInventory.where((i) => ((i['quantity'] as num?)?.toInt() ?? 0) == 0).length;
    _lowStock = allInventory.where((i) {
      final q = (i['quantity'] as num?)?.toInt() ?? 0;
      return q > 0 && q < 10;
    }).length;

    _lastUpdated = DateTime.now();
    // Update Recent Activity
    _updateActivity(todayOrders, allInventory, allReservations);
  }

  bool _isReservationOngoing(Map<String, dynamic> r) {
    try {
      final now = DateTime.now();
      final eventDate = r['event_date']?.toString();
      final startTime = r['start_time']?.toString();
      if (eventDate == null || startTime == null) return false;

      DateTime eventStart;
      if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
        DateTime parsedTime;
        try {
          parsedTime = DateFormat.jm().parse(startTime.trim());
        } catch (e) {
          String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
          parsedTime = DateFormat.jm().parse(fixedTime);
        }
        final parsedDate = DateTime.parse(eventDate);
        eventStart = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
      } else {
        String timeStr = startTime;
        if (timeStr.length == 5) timeStr = '$timeStr:00';
        eventStart = DateTime.parse('${eventDate}T$timeStr');
      }

      final durationValue = r['duration_hours'];
      int durationHours = 4; // Default
      if (durationValue is int) {
        durationHours = durationValue;
      } else if (durationValue is String) {
        durationHours = int.tryParse(durationValue) ?? 4;
      }

      final eventEnd = eventStart.add(Duration(hours: durationHours));
      
      // An event is "ongoing" if current time is after start AND before end.
      // However, usually we show it as "ongoing" even if it hasn't started yet but is today.
      // The user said "mawawala din yung event ongoing kapag tapos na yung event".
      // This implies we show it UNTIL it ends.
      return now.isBefore(eventEnd);
    } catch (_) {
      return true; // Fallback to show it if parsing fails
    }
  }

  List<double> _processChartData(List<Map<String, dynamic>> orders) {
    Map<int, double> dailyRevenue = {for (int i = 0; i < 7; i++) i: 0.0};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var order in orders) {
      final dateStr = order['created_at']?.toString();
      if (dateStr == null) continue;
      
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        final orderDate = DateTime(date.year, date.month, date.day);
        final diff = today.difference(orderDate).inDays;
        
        if (diff >= 0 && diff < 7) {
          dailyRevenue[6 - diff] = (dailyRevenue[6 - diff] ?? 0) + 
              ((order['total_amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
    }
    return dailyRevenue.values.toList();
  }

  void _updateActivity(
    List<Map<String, dynamic>> recentOrders, 
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> reservations,
  ) {
    List<_ActivityItem> activities = [];

    // Latest 2 Orders
    for (var i = 0; i < min(2, recentOrders.length); i++) {
      final o = recentOrders[i];
      final time = DateTime.tryParse(o['created_at'] ?? '');
      final timeStr = time != null ? DateFormat('HH:mm').format(time) : 'Just now';
      
      activities.add(_ActivityItem(
        icon: Icons.receipt_long,
        color: AppTheme.successGreen,
        title: 'Order #${o['transaction_id'] ?? o['id']} Completed',
        subtitle: '${o['customer_name'] ?? 'Guest'} · ₱${o['total_amount']}',
        time: timeStr,
      ));
    }

    // Latest Reservation (show confirmed or recent)
    if (reservations.isNotEmpty) {
      final r = reservations.first;
      final status = r['status']?.toString() ?? 'pending';
      final isConfirmed = status == 'confirmed';
      
      activities.add(_ActivityItem(
        icon: isConfirmed ? Icons.check_circle : Icons.event_available,
        color: isConfirmed ? AppTheme.successGreen : AppTheme.infoBlue,
        title: isConfirmed ? 'Reservation Confirmed' : 'New Reservation',
        subtitle: '${r['customer_name']} · ${r['event_type']}',
        time: 'Just now',
      ));
    }

    // Low Stock Alerts
    final lowStockItems = inventory.where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) < 10).take(2).toList();
    for (var item in lowStockItems) {
      activities.add(_ActivityItem(
        icon: Icons.inventory_2,
        color: AppTheme.warningOrange,
        title: 'Low Stock Alert',
        subtitle: '${item['item_name']} · ${item['quantity']} left',
        time: 'Now',
      ));
    }

    _recentActivity = activities;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersStream,
      builder: (context, orderSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _inventoryStream,
          builder: (context, invSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reservationsStream,
              builder: (context, resSnapshot) {
                final allOrders = orderSnapshot.data ?? [];
                final allInventory = invSnapshot.data ?? [];
                final allReservations = resSnapshot.data ?? [];
                
                _processData(allOrders, allInventory, allReservations);

                return FadeTransition(
                  opacity: _fadeIn,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: ResponsiveUtils.isMobile(context) 
                            ? const EdgeInsets.all(AppTheme.md)
                            : const EdgeInsets.all(AppTheme.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGreeting(context),
                        const SizedBox(height: AppTheme.xl),

                        // ── KPI Cards ──────────────────────────────
                        _buildSectionTitle(context, 'Today\'s Overview'),
                        const SizedBox(height: AppTheme.md),
                        _buildKpiGrid(isDesktop || isTablet),
                        const SizedBox(height: AppTheme.xl),

                        // ── Charts + Venue Status ──────────────────
                        ResponsiveUtils.isMobile(context)
                            ? Column(
                                children: [
                                  _buildRevenueChart(context),
                                  const SizedBox(height: AppTheme.lg),
                                  _buildVenueStatus(context),
                                ],
                              )
                            : (isDesktop || isTablet)
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: _buildRevenueChart(context)),
                                      const SizedBox(width: AppTheme.lg),
                                      Expanded(flex: 2, child: _buildVenueStatus(context)),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildRevenueChart(context),
                                      const SizedBox(height: AppTheme.lg),
                                      _buildVenueStatus(context),
                                    ],
                                  ),

                        const SizedBox(height: AppTheme.xl),

                        ResponsiveUtils.isMobile(context)
                            ? Column(
                                children: [
                                  _buildOperationsMonitor(context),
                                  const SizedBox(height: AppTheme.lg),
                                  _buildRecentActivity(context),
                                ],
                              )
                            : (isDesktop || isTablet)
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          children: [
                                            _buildOperationsMonitor(context),
                                            const SizedBox(height: AppTheme.lg),
                                            _buildRecentActivity(context),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildOperationsMonitor(context),
                                      const SizedBox(height: AppTheme.lg),
                                      _buildRecentActivity(context),
                                    ],
                                  ),

                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                      ),
                      // Real-time notification overlay
                      if (_showNewOrderNotification)
                        Positioned(
                          top: 20,
                          right: 20,
                          child: _buildNewOrderNotification(),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Greeting & Header ──────────────────────────────────────────────────
  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, Administrator!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.darkGrey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.8,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.mediumGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed,
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [AppTheme.primaryRed, AppTheme.primaryRedDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.sm + 2),
        Text(
          title, 
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ── KPI Grid ──────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(bool isWide) {
    final cards = [
      _KpiData(
        label: 'DAILY REVENUE',
        value: _formatNumber(_dailyRevenue),
        icon: Icons.payments_rounded,
        color: AppTheme.primaryRed,
        sub: '${_revenueGrowth >= 0 ? '+' : ''}${_revenueGrowth.toStringAsFixed(1)}% from yesterday',
        subPositive: _revenueGrowth >= 0,
        isHighlight: true,
      ),
      _KpiData(
        label: 'TOTAL ORDERS',
        value: '$_totalOrders',
        icon: Icons.shopping_cart_outlined,
        color: AppTheme.infoBlue,
        sub: '${_orderGrowth >= 0 ? '+' : ''}${_orderGrowth.toStringAsFixed(1)}%',
        subPositive: _orderGrowth >= 0,
        showProgress: true,
      ),
      _KpiData(
        label: 'CUSTOMERS TODAY',
        value: '$_totalCustomers',
        icon: Icons.people_outline,
        color: AppTheme.successGreen,
        sub: '${_customerGrowth >= 0 ? '+' : ''}${_customerGrowth.toStringAsFixed(1)}%',
        subPositive: _customerGrowth >= 0,
        extra: 'from yesterday',
      ),
      _KpiData(
        label: 'EVENT RESERVATIONS',
        value: '$_reservations',
        icon: Icons.confirmation_number_outlined,
        color: AppTheme.warningOrange,
        sub: _reservations > 0 ? 'Active' : 'No Events',
        subPositive: _reservations > 0,
        extra: 'Confirmed today',
      ),
    ];

    // Mobile: single column, Tablet: 2x2 grid, Desktop: 4 columns
    if (ResponsiveUtils.isMobile(context)) {
      return Column(
        children: cards
            .map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: _KpiCard(data: d),
                ))
            .toList(),
      );
    }

    if (isWide) {
      return Row(
        children: cards
            .map((d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppTheme.md),
                    child: _KpiCard(data: d),
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(data: cards[0])),
            const SizedBox(width: AppTheme.md),
            Expanded(child: _KpiCard(data: cards[1])),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        Row(
          children: [
            Expanded(child: _KpiCard(data: cards[2])),
            const SizedBox(width: AppTheme.md),
            Expanded(child: _KpiCard(data: cards[3])),
          ],
        ),
      ],
    );
  }

  // ── Revenue Chart ─────────────────────────────────────────────────────────
  Widget _buildRevenueChart(BuildContext context) {
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return DateFormat('E').format(date);
    });

    final maxRevenue = _weeklyRevenue.isEmpty ? 0.0 : _weeklyRevenue.reduce(max);
    final maxY = (maxRevenue == 0 ? 1000.0 : maxRevenue * 1.2).clamp(1000.0, 10000000.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Revenue Performance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Last 7 Days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.mediumGrey),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xxl),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.darkGrey,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      _formatNumber(rod.toY.toInt()),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          dayLabels[value.toInt() % 7],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyRevenue[i],
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        width: 28,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppTheme.backgroundColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Venue Status ──────────────────────────────────────────────────────────
  Widget _buildVenueStatus(BuildContext context) {
    // Determine status based on reservations today
    final isReserved = _reservations > 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue Status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
          ),
          const SizedBox(height: AppTheme.xxl),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 75,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        color: isReserved ? AppTheme.primaryRed : AppTheme.backgroundColor,
                        value: isReserved ? 100 : 0,
                        title: '',
                        radius: 25,
                      ),
                      PieChartSectionData(
                        color: isReserved ? AppTheme.backgroundColor : AppTheme.successGreen.withValues(alpha: 0.1),
                        value: isReserved ? 0 : 100,
                        title: '',
                        radius: 20,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isReserved ? 'BOOKED' : 'OPEN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isReserved ? AppTheme.primaryRed : AppTheme.successGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isReserved ? 'Event in progress' : 'Ready for Guests',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.xxl),
          _statusLegendRow(
            isReserved ? AppTheme.primaryRed : AppTheme.successGreen,
            isReserved ? 'Venue Occupied' : 'Venue Available',
            isReserved ? 'Currently hosting an event' : 'No reservations today',
          ),
        ],
      ),
    );
  }

  Widget _statusLegendRow(Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            title.contains('Occupied') ? Icons.event_busy : Icons.event_available,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.darkGrey,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildOperationsMonitor(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Operations Monitor',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppTheme.successGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('REAL-TIME', style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xxl),
          _monitorRow('Pending Orders', _pendingOrders.toString(), AppTheme.warningOrange),
          const SizedBox(height: 16),
          _monitorRow('In Preparation', _preparingOrders.toString(), AppTheme.infoBlue),
          const SizedBox(height: 16),
          _monitorRow('Ready for Pickup', _readyOrders.toString(), AppTheme.successGreen),
          const Divider(height: 32, color: AppTheme.lightGrey),
          _monitorRow('Out of Stock Items', _outOfStock.toString(), AppTheme.errorRed),
          const SizedBox(height: 16),
          _monitorRow('Low Stock Alerts', _lowStock.toString(), AppTheme.warningOrange),
        ],
      ),
    );
  }

  Widget _monitorRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.darkGrey)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────
  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
              ),
              Text(
                'View All Activity',
                style: TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xl),
          if (_recentActivity.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No recent activity')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(_recentActivity.length, 5),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _ActivityTile(item: _recentActivity[index]),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _formatNumber(dynamic n) {
    final numValue = n is double ? n : (n as int).toDouble();
    if (numValue >= 1000000) return '₱${(numValue / 1000000).toStringAsFixed(1)}m';
    if (numValue >= 10000) return '₱${(numValue / 1000).toStringAsFixed(0)}k';
    // For amounts under 10k, show the exact amount with proper formatting
    return '₱${numValue.toStringAsFixed(numValue.truncate() == numValue ? 0 : 1)}';
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // ── Real-time Notification Widget ───────────────────────────────────────
  Widget _buildNewOrderNotification() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NEW ORDER!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _newOrderAmount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  final bool? subPositive; // null = neutral
  final bool isHighlight;
  final bool showProgress;
  final String? extra;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
    required this.subPositive,
    this.isHighlight = false,
    this.showProgress = false,
    this.extra,
  });
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}


// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isHighlight) return _buildHighlightCard();

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              if (data.subPositive != null || !data.showProgress)
                Text(
                  data.sub,
                  style: TextStyle(
                    color: data.sub == 'High' ? AppTheme.errorRed : (data.subPositive == true ? AppTheme.successGreen : AppTheme.mediumGrey),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.xl),
          Text(
            data.label,
            style: const TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          if (data.showProgress)
            _buildProgressBar()
          else if (data.extra != null)
            Text(
              data.extra!,
              style: const TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    data.sub,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.restaurant, color: Colors.white.withValues(alpha: 0.2), size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.65,
            child: Container(
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.mediumGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

