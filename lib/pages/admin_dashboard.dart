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
  int _dailyRevenue = 0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _reservations = 0;
  int _occupiedTables = 0;
  static const int _totalTables = 20;

  // ── Weekly revenue bars (now derived from streams) ───────────────────────
  List<double> _weeklyRevenue = List.filled(7, 0.0);

  // ── Recent activity (now derived from streams) ───────────────────────────
  List<_ActivityItem> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _ordersStream = _supabase.from('orders').stream(primaryKey: ['id']).order('created_at', ascending: false);
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
    // KPI Data
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final todayOrders = allOrders.where((o) => (o['created_at']?.toString() ?? '').startsWith(todayStr)).toList();
    
    _dailyRevenue = todayOrders.fold(0, (sum, o) => sum + ((o['total_amount'] as num?)?.toInt() ?? 0));
    _totalOrders = todayOrders.length;
    
    Set<String> uniqueCustomers = {};
    for (var o in todayOrders) {
      uniqueCustomers.add(o['customer_name'] ?? 'Guest');
    }
    _totalCustomers = uniqueCustomers.length;
    
    // Reservations (Events)
    final todayReservations = allReservations.where((r) => (r['created_at']?.toString() ?? '').startsWith(todayStr)).toList();
    _reservations = todayReservations.length;

    // Weekly Revenue
    _weeklyRevenue = _processChartData(allOrders);

    // Occupied Tables / Capacity
    _occupiedTables = todayOrders.length % _totalTables;

    // Recent Activity
    _updateActivity(todayOrders, allInventory, allReservations);
  }

  List<double> _processChartData(List<Map<String, dynamic>> orders) {
    Map<int, double> dailyRevenue = {for (int i = 0; i < 7; i++) i: 0.0};
    final now = DateTime.now();

    for (var order in orders) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date != null) {
        final diff = now.difference(date).inDays;
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

    // Latest Reservation
    if (reservations.isNotEmpty) {
      final r = reservations.first;
      activities.add(_ActivityItem(
        icon: Icons.event_available,
        color: AppTheme.infoBlue,
        title: 'New Reservation',
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
              child: SingleChildScrollView(
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

            // ── Quick Actions + Recent Activity ────────
            ResponsiveUtils.isMobile(context)
                ? Column(
                    children: [
                      _buildQuickActions(context),
                      const SizedBox(height: AppTheme.lg),
                      _buildRecentActivity(context),
                    ],
                  )
                : (isDesktop || isTablet)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildQuickActions(context)),
                          const SizedBox(width: AppTheme.lg),
                          Expanded(flex: 3, child: _buildRecentActivity(context)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildQuickActions(context),
                          const SizedBox(height: AppTheme.lg),
                          _buildRecentActivity(context),
                        ],
                      ),

                  const SizedBox(height: AppTheme.xxl),
                ],
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

  // ── Greeting ─────────────────────────────────────────────────────────────
  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryRed, AppTheme.primaryRedDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, Administrator!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  _formatDate(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.white.withValues(alpha: 0.85),
                      ),
                ),
                const SizedBox(height: AppTheme.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.md, vertical: AppTheme.xs + 2),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withValues(alpha: 0.2),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Text(
                  '$_occupiedTables / $_totalTables capacity',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.restaurant, color: Colors.white24, size: 72),
        ],
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppTheme.sm),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  // ── KPI Grid ──────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(bool isWide) {
    final cards = [
      _KpiData(
        label: 'Daily Revenue',
        value: '₱${_formatNumber(_dailyRevenue)}',
        icon: Icons.payments_rounded,
        color: AppTheme.successGreen,
        sub: '+12% vs yesterday',
        subPositive: true,
      ),
      _KpiData(
        label: 'Total Orders',
        value: '$_totalOrders',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.infoBlue,
        sub: '+8 in the last hour',
        subPositive: true,
      ),
      _KpiData(
        label: 'Customers Today',
        value: '$_totalCustomers',
        icon: Icons.people_rounded,
        color: AppTheme.warningOrange,
        sub: 'Avg ₱${(_dailyRevenue ~/ max(_totalCustomers, 1))} per head',
        subPositive: null,
      ),
      _KpiData(
        label: 'Event Reservations',
        value: '$_reservations',
        icon: Icons.confirmation_number_rounded,
        color: AppTheme.primaryRed,
        sub: _reservations > 5 ? 'High demand today' : 'Moderate bookings',
        subPositive: _reservations > 5,
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = (_weeklyRevenue.reduce(max) * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Weekly Revenue'),
          const SizedBox(height: AppTheme.lg),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppTheme.darkGrey.withValues(alpha: 0.9),
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '₱${_formatNumber(rod.toY.toInt())}',
                      const TextStyle(color: AppTheme.white, fontSize: 12),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          days[value.toInt() % 7],
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.mediumGrey),
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppTheme.lightGrey,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyRevenue[i],
                        color: i == 6
                            ? AppTheme.primaryRed
                            : AppTheme.primaryRedLight.withValues(alpha: 0.65),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Center(
            child: Text(
              'This week · ₱${_formatNumber(_weeklyRevenue.reduce((a, b) => a + b).toInt())} total',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.mediumGrey),
            ),
          ),
        ],
      ),
    );
  }

  // ── Venue Status ──────────────────────────────────────────────────────────
  Widget _buildVenueStatus(BuildContext context) {
    final available = _totalTables - _occupiedTables;
    final pct = (_occupiedTables / _totalTables * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Venue Occupancy'),
          const SizedBox(height: AppTheme.lg),
          // Donut chart using fl_chart
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 48,
                sections: [
                  PieChartSectionData(
                    color: AppTheme.primaryRed,
                    value: _occupiedTables.toDouble(),
                    title: '$_occupiedTables\nOccupied',
                    titleStyle: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 55,
                  ),
                  PieChartSectionData(
                    color: AppTheme.lightGrey,
                    value: available.toDouble(),
                    title: '$available\nFree',
                    titleStyle: const TextStyle(
                      color: AppTheme.mediumGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.md),
          _venueStatusRow(
              Icons.circle, AppTheme.primaryRed, 'Booked', '$_occupiedTables slots'),
          const SizedBox(height: AppTheme.xs),
          _venueStatusRow(
              Icons.circle, AppTheme.lightGrey, 'Available', '$available slots'),
          const SizedBox(height: AppTheme.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
            decoration: BoxDecoration(
              color: pct >= 80
                  ? AppTheme.errorRed.withValues(alpha: 0.1)
                  : AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Center(
              child: Text(
                '$pct% Full · ${pct >= 80 ? "High demand" : "Normal load"}',
                style: TextStyle(
                  color: pct >= 80 ? AppTheme.errorRed : AppTheme.successGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueStatusRow(
      IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: AppTheme.sm),
        Text(label,
            style: const TextStyle(
                color: AppTheme.mediumGrey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
          icon: Icons.receipt_long_rounded,
          label: 'New Order',
          color: AppTheme.primaryRed),
      _QuickAction(
          icon: Icons.event_available_rounded,
          label: 'Event Reservation',
          color: AppTheme.infoBlue),
      _QuickAction(
          icon: Icons.inventory_2_rounded,
          label: 'Check Stock',
          color: AppTheme.warningOrange),
      _QuickAction(
          icon: Icons.bar_chart_rounded,
          label: 'Sales Report',
          color: AppTheme.successGreen),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Quick Actions'),
          const SizedBox(height: AppTheme.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppTheme.md,
            crossAxisSpacing: AppTheme.md,
            childAspectRatio: 1.5,
            children: actions
                .map((a) => _QuickActionCard(action: a))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────
  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(context, 'Recent Activity'),
              TextButton(
                onPressed: () {},
                child: const Text('View All',
                    style: TextStyle(color: AppTheme.primaryRed)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          ..._recentActivity.map((item) => _ActivityTile(item: item)),
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

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
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
}

// ── Data models ───────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  final bool? subPositive; // null = neutral

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
    required this.subPositive,
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

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subColor = data.subPositive == null
        ? AppTheme.mediumGrey
        : data.subPositive!
            ? AppTheme.successGreen
            : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            data.sub,
            style: TextStyle(color: subColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.sm),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(item.subtitle,
                    style: const TextStyle(
                        color: AppTheme.mediumGrey, fontSize: 12)),
              ],
            ),
          ),
          Text(item.time,
              style:
                  const TextStyle(color: AppTheme.mediumGrey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 28),
              const SizedBox(height: AppTheme.xs),
              Text(
                action.label,
                style: TextStyle(
                  color: action.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
