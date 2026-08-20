import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class InventoryForecastPage extends StatefulWidget {
  const InventoryForecastPage({super.key});

  @override
  State<InventoryForecastPage> createState() => _InventoryForecastPageState();
}

class _InventoryForecastPageState extends State<InventoryForecastPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'Daily';
  String _selectedDailyMonth = 'January';
  String _selectedDailyDay = '1';
  String _selectedWeeklyMonth = 'January';
  String _selectedWeekFilter = 'Week 1';
  String _selectedMonthFilter = 'January';
  String _selectedYearFilter = DateTime.now().year.toString();
  String _selectedViewMode = 'Chart'; // 'Chart', 'Feed', 'Deficit'

  List<Map<String, dynamic>> _forecastItems = [];
  bool _isLoading = true;
  StreamSubscription? _requestsSubscription;
  Timer? _pollingTimer;

  final List<String> timeFilters = ['Daily', 'Weekly', 'Monthly', 'Annually'];
  final List<String> dayFilters = List.generate(31, (index) => (index + 1).toString());
  final List<String> weekFilters = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
  final List<String> monthFilters = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<String> yearFilters = List.generate(
    2031 - DateTime.now().year + 1,
    (index) => (DateTime.now().year + index).toString(),
  );

  static const List<String> categories = [
    'All',
    'Fresh',
    'Roasting',
    'Davids',
    'Groceries',
    'Sauces',
    'Vegetables',
    'Pre-mix',
    'Drinks',
    'Packaging',
    'Janitorial',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDailyMonth = monthFilters[now.month - 1];
    _selectedDailyDay = now.day.toString();
    _selectedWeeklyMonth = monthFilters[now.month - 1];
    _selectedMonthFilter = monthFilters[now.month - 1];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Initial load
    _fetchForecastData();

    // Live update stream & background silent poll
    _subscribeToKitchenRequests();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchForecastData(silent: true);
    });
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _subscribeToKitchenRequests() {
    try {
      _requestsSubscription = Supabase.instance.client
          .from('kitchen_requests')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) _fetchForecastData(silent: true);
          }, onError: (e) {
            debugPrint('Kitchen requests realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  // ── Fetch Full Demand & Consumption Pipeline for Accurate Forecasting ─────
  Future<void> _fetchForecastData({bool silent = false}) async {
    if (!silent && _forecastItems.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final inventoryResponse = await Supabase.instance.client
          .from('inventory')
          .select()
          .order('name');

      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

      // Fetch all kitchen demand tickets for forecasting (both approved consumption and pending)
      final transactionsResponse = await Supabase.instance.client
          .from('kitchen_requests')
          .select()
          .gte('created_at', cutoffDate.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final calculated = _calculateForecast(
        List<Map<String, dynamic>>.from(inventoryResponse),
        List<Map<String, dynamic>>.from(transactionsResponse),
      );

      if (mounted) {
        setState(() {
          _forecastItems = calculated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _calculateForecast(
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> transactions,
  ) {
    List<Map<String, dynamic>> forecast = [];

    final Map<String, Map<String, dynamic>> inventoryMap = {};
    for (var item in inventory) {
      inventoryMap[item['name'] as String] = item;
    }

    for (var transaction in transactions) {
      final itemName = transaction['item_name'] as String;
      final inventoryItem = inventoryMap[itemName];

      if (inventoryItem == null) continue;

      final currentStock = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
      final unit = transaction['unit'] as String? ?? 'pcs';
      final requestQuantity = (transaction['quantity_needed'] as num?)?.toInt() ?? 0;
      final priority = transaction['priority'] as String? ?? 'Medium';
      final storageRoom = inventoryItem['storage_room']?.toString() ?? 'Dry Storage';
      final status = transaction['status']?.toString() ?? 'Approved';

      forecast.add({
        'name': itemName,
        'category': inventoryItem['category'] ?? 'Uncategorized',
        'currentStock': currentStock,
        'unit': unit,
        'requestQuantity': requestQuantity,
        'priority': priority,
        'status': status,
        'storage_room': storageRoom,
        'riskColor': _getPriorityColor(priority),
        'riskIcon': _getPriorityIcon(priority),
        'requestId': transaction['id'],
        'requestedBy': transaction['requested_by'],
        'createdAt': transaction['created_at'],
        'notes': transaction['notes'],
      });
    }

    forecast.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt'] as String);
      final dateB = DateTime.parse(b['createdAt'] as String);
      return dateB.compareTo(dateA);
    });

    return forecast;
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return const Color(0xFFEF4444);
      case 'Medium':
      case 'Normal':
        return const Color(0xFFF59E0B);
      case 'Low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return Icons.priority_high_rounded;
      case 'Medium':
      case 'Normal':
        return Icons.warning_amber_rounded;
      case 'Low':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  List<Map<String, dynamic>> _filterDataByTime(List<Map<String, dynamic>> forecast) {
    if (forecast.isEmpty) return [];

    final now = DateTime.now();
    final List<Map<String, dynamic>> filteredData = [];

    for (var item in forecast) {
      final createdAt = DateTime.parse(item['createdAt'] as String).toLocal();

      switch (_selectedTimeFilter) {
        case 'Daily':
          final selectedMonthIndex = _getMonthIndex(_selectedDailyMonth);
          final selectedDay = int.parse(_selectedDailyDay);
          if (createdAt.year == now.year &&
              createdAt.month == selectedMonthIndex &&
              createdAt.day == selectedDay) {
            filteredData.add(item);
          }
          break;

        case 'Weekly':
          final selectedWeekNumber = int.parse(_selectedWeekFilter.split(' ')[1]);
          final selectedMonthIndex = _getMonthIndex(_selectedWeeklyMonth);
          if (_isInSelectedWeekOfMonth(createdAt, selectedWeekNumber, selectedMonthIndex, now.year)) {
            filteredData.add(item);
          }
          break;

        case 'Monthly':
          final selectedMonthIndex = _getMonthIndex(_selectedMonthFilter);
          if (createdAt.year == now.year && createdAt.month == selectedMonthIndex) {
            filteredData.add(item);
          }
          break;

        case 'Annually':
          final selectedYear = int.parse(_selectedYearFilter);
          if (createdAt.year == selectedYear) {
            filteredData.add(item);
          }
          break;
      }
    }

    return filteredData;
  }

  int _getMonthIndex(String monthName) {
    switch (monthName) {
      case 'January': return 1;
      case 'February': return 2;
      case 'March': return 3;
      case 'April': return 4;
      case 'May': return 5;
      case 'June': return 6;
      case 'July': return 7;
      case 'August': return 8;
      case 'September': return 9;
      case 'October': return 10;
      case 'November': return 11;
      case 'December': return 12;
      default: return 1;
    }
  }

  bool _isInSelectedWeekOfMonth(DateTime date, int weekNumber, int monthIndex, int year) {
    final firstDayOfMonth = DateTime(year, monthIndex, 1);
    final weekStart = firstDayOfMonth.add(Duration(days: (weekNumber - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return date.year == year &&
        date.month == monthIndex &&
        date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  double _getBarChartMaxY() {
    switch (_selectedTimeFilter) {
      case 'Daily': return 150;
      case 'Weekly': return 300;
      case 'Monthly': return 800;
      case 'Annually': return 4000;
      default: return 100;
    }
  }

  Map<String, dynamic> _getTopItemsData(List<Map<String, dynamic>> forecast) {
    final timeFilteredData = _filterDataByTime(forecast);
    if (timeFilteredData.isEmpty) {
      return {
        'barGroups': <BarChartGroupData>[],
        'topItems': <MapEntry<String, double>>[],
      };
    }

    final Map<String, double> itemTotals = {};
    for (var item in timeFilteredData) {
      final itemName = item['name'] as String;
      final quantity = (item['requestQuantity'] as num).toDouble();
      itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
    }

    final sortedItems = itemTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sortedItems.take(8).toList();

    final barGroups = List.generate(topItems.length, (index) {
      final item = topItems[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.value,
            gradient: const LinearGradient(
              colors: [Color(0xFF14332E), Color(0xFF2E7D32)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    return {
      'barGroups': barGroups,
      'topItems': topItems,
    };
  }

  // ── Mark Request as Given / Dispensed ──────────────────────────────────────
  Future<void> _markRequestAsGiven(Map<String, dynamic> item) async {
    final requestId = item['requestId'];
    if (requestId == null) return;

    try {
      await Supabase.instance.client
          .from('kitchen_requests')
          .update({
            'status': 'Approved',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);

      _fetchForecastData(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['name']} marked as fulfilled / given to Kitchen!'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Apply category filtering in memory (0ms delay)
    var categoryFiltered = _forecastItems;
    if (_selectedCategory != 'All') {
      categoryFiltered = _forecastItems
          .where((item) => item['category'] == _selectedCategory)
          .toList();
    }

    final timeFiltered = _filterDataByTime(categoryFiltered);

    // Calculations for 4 Executive KPI Cards
    final totalTickets = timeFiltered.length;
    final urgentCount = timeFiltered.where((i) =>
        i['priority'] == 'High' || i['priority'] == 'Urgent').length;

    int deficitCount = 0;
    int totalUnitsRequested = 0;

    for (var item in timeFiltered) {
      final req = item['requestQuantity'] as int;
      final stock = item['currentStock'] as int;
      totalUnitsRequested += req;
      if (stock < req) {
        deficitCount++;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Executive Header Banner ──────────────────────────────
                _buildExecutiveHeader(isMobile),

                const SizedBox(height: 16),

                if (_isLoading && _forecastItems.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF14332E)),
                    ),
                  )
                else ...[
                  // ── 4 Top KPI Cards ──────────────────────────────
                  _buildKpiMetricsRow(
                    totalTickets: totalTickets,
                    totalUnits: totalUnitsRequested,
                    urgentCount: urgentCount,
                    deficitCount: deficitCount,
                    isMobile: isMobile,
                  ),

                  const SizedBox(height: 16),

                  // ── Filter Controls Section ──────────────────────
                  _buildFilterControls(isMobile),

                  const SizedBox(height: 16),

                  // ── View Mode Selector & Content ─────────────────
                  _buildMainContent(categoryFiltered, timeFiltered, isMobile),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Executive Header Banner ────────────────────────────────────────────────
  Widget _buildExecutiveHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14332E), Color(0xFF1B4942), Color(0xFF163C35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: AppTheme.warmGold, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Kitchen Demand & Inventory Forecast',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Historical consumption trends, ingredient burn rates, and procurement forecasting',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _fetchForecastData(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Demand Forecast',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4 Top KPI Cards ────────────────────────────────────────────────────────
  Widget _buildKpiMetricsRow({
    required int totalTickets,
    required int totalUnits,
    required int urgentCount,
    required int deficitCount,
    required bool isMobile,
  }) {
    final cards = [
      _buildKpiCard(
        title: 'REQUISITION TICKETS',
        value: '$totalTickets Tickets',
        subtitle: 'Total demand requests',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF14332E),
      ),
      _buildKpiCard(
        title: 'DEMAND VOLUME',
        value: '$totalUnits Units',
        subtitle: 'Total ingredient volume requested',
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF3B82F6),
      ),
      _buildKpiCard(
        title: 'HIGH & URGENT DEMAND',
        value: '$urgentCount Items',
        subtitle: urgentCount > 0 ? 'High priority consumption' : 'Normal kitchen demand',
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFF59E0B),
        isAlert: urgentCount > 0,
      ),
      _buildKpiCard(
        title: 'STOCK DEFICIT ALERTS',
        value: '$deficitCount SKUs',
        subtitle: deficitCount > 0 ? 'Demand exceeds current stock' : 'Sufficient stock buffer',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFEF4444),
        isAlert: deficitCount > 0,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 122,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: cards.map((c) => Container(
            width: 200,
            margin: const EdgeInsets.only(right: 10),
            child: c,
          )).toList(),
        ),
      );
    }

    return Row(
      children: cards.map((card) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: card,
      ))).toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isAlert ? 0.35 : 0.15),
          width: isAlert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isAlert ? 0.08 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Filter Controls Section ────────────────────────────────────────────────
  Widget _buildFilterControls(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period + Sub-Period Row
          if (isMobile) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.adminMainBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: timeFilters.map((period) {
                    final isSel = _selectedTimeFilter == period;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTimeFilter = period),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF14332E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.darkGrey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSecondaryTimeDropdown(),
          ] else ...[
            Row(
              children: [
                // Period Toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.adminMainBackground.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: timeFilters.map((period) {
                      final isSel = _selectedTimeFilter == period;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTimeFilter = period),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF14332E) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            period,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? Colors.white : AppTheme.darkGrey,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 10),

                // Secondary Sub-Period Selector
                Expanded(child: _buildSecondaryTimeDropdown()),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Category Carousel Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    backgroundColor: AppTheme.adminMainBackground.withValues(alpha: 0.5),
                    selectedColor: const Color(0xFF14332E),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkGrey,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF14332E) : AppTheme.cardBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryTimeDropdown() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: _styledDropdown(
                value: _selectedDailyMonth,
                items: monthFilters,
                onChanged: (v) => setState(() => _selectedDailyMonth = v!),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _styledDropdown(
                value: _selectedDailyDay,
                items: dayFilters,
                prefix: 'Day ',
                onChanged: (v) => setState(() => _selectedDailyDay = v!),
              ),
            ),
          ],
        );

      case 'Weekly':
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: _styledDropdown(
                value: _selectedWeeklyMonth,
                items: monthFilters,
                onChanged: (v) => setState(() => _selectedWeeklyMonth = v!),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _styledDropdown(
                value: _selectedWeekFilter,
                items: weekFilters,
                onChanged: (v) => setState(() => _selectedWeekFilter = v!),
              ),
            ),
          ],
        );

      case 'Monthly':
        return _styledDropdown(
          value: _selectedMonthFilter,
          items: monthFilters,
          onChanged: (v) => setState(() => _selectedMonthFilter = v!),
        );

      case 'Annually':
        return _styledDropdown(
          value: _selectedYearFilter,
          items: yearFilters,
          onChanged: (v) => setState(() => _selectedYearFilter = v!),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _styledDropdown({
    required String value,
    required List<String> items,
    String prefix = '',
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGrey),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF14332E)),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text('$prefix$i'))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Main Content Section ───────────────────────────────────────────────────
  Widget _buildMainContent(
    List<Map<String, dynamic>> categoryFiltered,
    List<Map<String, dynamic>> timeFiltered,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View Mode Switcher Header
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _viewModeTab('Chart', Icons.bar_chart_rounded, 'Demand Analytics'),
                    const SizedBox(width: 6),
                    _viewModeTab('Feed', Icons.format_list_bulleted_rounded, 'Demand Queue'),
                    const SizedBox(width: 6),
                    _viewModeTab('Deficit', Icons.warning_amber_rounded, 'Stock Deficits'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${timeFiltered.length} demand records',
                  style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _viewModeTab('Chart', Icons.bar_chart_rounded, 'Demand Analytics'),
                  const SizedBox(width: 6),
                  _viewModeTab('Feed', Icons.format_list_bulleted_rounded, 'Demand Queue'),
                  const SizedBox(width: 6),
                  _viewModeTab('Deficit', Icons.warning_amber_rounded, 'Stock Deficits'),
                ],
              ),
              Text(
                '${timeFiltered.length} demand records',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey, fontWeight: FontWeight.bold),
              ),
            ],
          ),

        const SizedBox(height: 12),

        if (timeFiltered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.query_stats_rounded, size: 48, color: AppTheme.mediumGrey),
                  SizedBox(height: 12),
                  Text('No kitchen demand records in this timeframe',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGrey)),
                  SizedBox(height: 4),
                  Text('Try switching to another month, week, or select "Monthly"',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey)),
                ],
              ),
            ),
          )
        else if (_selectedViewMode == 'Chart')
          _buildBarChartCard(categoryFiltered)
        else if (_selectedViewMode == 'Deficit')
          _buildDeficitMatrix(timeFiltered, isMobile)
        else
          _buildDemandFeed(timeFiltered, isMobile),
      ],
    );
  }

  Widget _viewModeTab(String mode, IconData icon, String label) {
    final isSelected = _selectedViewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedViewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF14332E) : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.darkGrey),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Demand Bar Chart Card ──────────────────────────────────────────────
  Widget _buildBarChartCard(List<Map<String, dynamic>> forecast) {
    final chartData = _getTopItemsData(forecast);
    final barGroups = chartData['barGroups'] as List<BarChartGroupData>;
    final topItems = chartData['topItems'] as List<MapEntry<String, double>>;

    if (topItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Center(child: Text('No demand records to graph.')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Kitchen Ingredients by Consumption',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Highest requested supplies for $_selectedTimeFilter',
                    style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Top ${topItems.length} SKUs',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF14332E)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getBarChartMaxY(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF14332E),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = topItems[group.x];
                      return BarTooltipItem(
                        '${item.key}\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} units consumed',
                            style: const TextStyle(color: AppTheme.warmGold, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 9.5, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < topItems.length) {
                          final label = topItems[index].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label.length > 8 ? '${label.substring(0, 7)}…' : label,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.cardBorder,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reorder / Stock Deficit Matrix View ─────────────────────────────────────
  Widget _buildDeficitMatrix(List<Map<String, dynamic>> items, bool isMobile) {
    final deficitItems = items.where((i) {
      final req = i['requestQuantity'] as int;
      final stock = i['currentStock'] as int;
      return stock < req;
    }).toList();

    if (deficitItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.successGreen, size: 44),
              SizedBox(height: 10),
              Text('No Stock Deficits Detected',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGrey)),
              SizedBox(height: 4),
              Text('All requested ingredients in this timeframe were covered by available inventory.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: deficitItems.length,
      itemBuilder: (context, index) {
        return _buildDemandCard(deficitItems[index], isDeficitView: true);
      },
    );
  }

  // ── Demand Feed View ───────────────────────────────────────────────────────
  Widget _buildDemandFeed(List<Map<String, dynamic>> items, bool isMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildDemandCard(items[index], isDeficitView: false);
      },
    );
  }

  Widget _buildDemandCard(Map<String, dynamic> item, {required bool isDeficitView}) {
    final name = item['name'] as String;
    final category = item['category'] as String;
    final unit = item['unit'] as String;
    final reqQty = item['requestQuantity'] as int;
    final currentStock = item['currentStock'] as int;
    final priority = item['priority'] as String;
    final priorityColor = item['riskColor'] as Color;
    final priorityIcon = item['riskIcon'] as IconData;
    final storageRoom = item['storage_room'] as String;
    final requestedBy = item['requestedBy']?.toString() ?? 'Chef / Kitchen';
    final notes = item['notes']?.toString() ?? '';
    final status = (item['status']?.toString() ?? 'Approved').toLowerCase();
    final isPending = status == 'pending';

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(item['createdAt'] as String).toLocal();
    } catch (_) {}

    final deficit = reqQty - currentStock;
    final hasDeficit = deficit > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDeficit ? const Color(0xFFEF4444).withValues(alpha: 0.3) : AppTheme.cardBorder,
          width: hasDeficit ? 1.5 : 1,
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
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(priorityIcon, size: 16, color: priorityColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$category • $storageRoom',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Status Badge (Fulfilled vs Pending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                          : const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPending
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                            : const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isPending ? 'PENDING' : 'FULFILLED',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: priorityColor),
                    ),
                  ),

                  if (isPending)
                    ElevatedButton.icon(
                      onPressed: () => _markRequestAsGiven(item),
                      icon: const Icon(Icons.check_rounded, size: 12),
                      label: const Text('Dispense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14332E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Side-by-Side Numbers & Deficit Callout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KITCHEN DEMAND',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey)),
                      const SizedBox(height: 2),
                      Text('$reqQty $unit',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.darkGrey)),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT IN-STOCK',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey)),
                      const SizedBox(height: 2),
                      Text('$currentStock $unit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: currentStock == 0 ? const Color(0xFFEF4444) : AppTheme.darkGrey,
                          )),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.cardBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROCURING STATUS',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey)),
                      const SizedBox(height: 2),
                      Text(
                        hasDeficit ? 'Deficit: -$deficit $unit' : 'Covered in stock',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: hasDeficit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  notes.isNotEmpty ? 'Note: $notes' : 'Requested by $requestedBy',
                  style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.mediumGrey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('MMM d, h:mm a').format(createdAt),
                  style: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
