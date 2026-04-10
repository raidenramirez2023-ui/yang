import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class InventoryForecastPage extends StatefulWidget {
  const InventoryForecastPage({super.key});

  @override
  State<InventoryForecastPage> createState() => _InventoryForecastPageState();
}

class _InventoryForecastPageState extends State<InventoryForecastPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _selectedPeriod = '7days';
  String _selectedCategory = 'All';
  String _selectedItemName = 'All';
  String _selectedTimeFilter = 'Daily'; // New time filter for Daily/Weekly/Monthly
  String _selectedDayFilter = 'Monday'; // Secondary filter for Daily (Monday-Sunday)
  String _selectedWeekFilter = 'Week 1'; // Secondary filter for Weekly (Week 1-4)
  String _selectedMonthFilter = 'January'; // Secondary filter for Monthly (January-April)
  bool _showChart = true; // Toggle between chart and list
  late Future<List<Map<String, dynamic>>> _forecastFuture;

  final List<String> periods = ['7days', '31days', '90days'];
  final List<String> timeFilters = ['Daily', 'Weekly', 'Monthly'];
  final List<String> dayFilters = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> weekFilters = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
  final List<String> monthFilters = ['January', 'February', 'March', 'April'];
  final List<String> categories = [
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
  List<String> itemNames = ['All'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _forecastFuture = _getForecastData();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getForecastData() async {
    try {
      // Get current inventory
      final inventoryResponse = await Supabase.instance.client
          .from('inventory')
          .select()
          .order('name');

      // Get approved kitchen requests for selected period
      final days = _getDaysFromPeriod(_selectedPeriod);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final transactionsResponse = await Supabase.instance.client
          .from('kitchen_requests')
          .select()
          .eq('status', 'Approved')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: false);

      final inventory = inventoryResponse;
      final transactions = transactionsResponse;

      // Update item names list for filtering
      final Set<String> uniqueItems = <String>{};
      for (var transaction in transactions) {
        final itemName = transaction['item_name'] as String;
        uniqueItems.add(itemName);
      }

      setState(() {
        itemNames = ['All', ...uniqueItems.toList()..sort()];
      });

      return _calculateForecast(inventory, transactions, days);
    } catch (e) {
      return [];
    }
  }

  int _getDaysFromPeriod(String period) {
    switch (period) {
      case '7days':
        return 7;
      case '30days':
        return 30;
      case '90days':
        return 90;
      default:
        return 7;
    }
  }

  List<Map<String, dynamic>> _calculateForecast(
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> transactions,
    int periodDays,
  ) {
    List<Map<String, dynamic>> forecast = [];

    // Create a map of inventory items for quick lookup
    final Map<String, Map<String, dynamic>> inventoryMap = {};
    for (var item in inventory) {
      inventoryMap[item['name'] as String] = item;
    }

    // Create a separate forecast entry for each approved kitchen request
    for (var transaction in transactions) {
      final itemName = transaction['item_name'] as String;
      final inventoryItem = inventoryMap[itemName];

      // Only include if item exists in inventory
      if (inventoryItem == null) {
        continue;
      }

      final currentStock = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
      final unit = transaction['unit'] as String? ?? 'pcs';
      final requestQuantity =
          (transaction['quantity_needed'] as num?)?.toInt() ?? 0;
      final priority = transaction['priority'] as String? ?? 'Medium';

      forecast.add({
        'name': itemName,
        'category': inventoryItem['category'] ?? 'Uncategorized',
        'currentStock': currentStock,
        'unit': unit,
        'requestQuantity': requestQuantity,
        'priority': priority,
        'riskColor': _getPriorityColor(priority),
        'riskIcon': _getPriorityIcon(priority),
        'requestId': transaction['id'],
        'requestedBy': transaction['requested_by'],
        'createdAt': transaction['created_at'],
        'notes': transaction['notes'],
      });
    }

    // Sort by creation date (newest first) - same as Kitchen Stock Requests queuing
    forecast.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt'] as String);
      final dateB = DateTime.parse(b['createdAt'] as String);
      return dateB.compareTo(dateA); // Newest first
    });

    return forecast;
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return AppTheme.errorRed;
      case 'Medium':
      case 'Normal':
        return AppTheme.warningOrange;
      case 'Low':
        return AppTheme.successGreen;
      default:
        return AppTheme.infoBlue;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return Icons.priority_high_rounded;
      case 'Medium':
      case 'Normal':
        return Icons.info_rounded;
      case 'Low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  List<FlSpot> _getChartData(List<Map<String, dynamic>> forecast) {
    if (forecast.isEmpty) return [];

    // Group requests by day of week and sum quantities
    final Map<int, double> dailyTotals = {
      1: 0.0, // Monday
      2: 0.0, // Tuesday
      3: 0.0, // Wednesday
      4: 0.0, // Thursday
      5: 0.0, // Friday
      6: 0.0, // Saturday
      7: 0.0, // Sunday
    };

    for (var item in forecast) {
      final date = DateTime.parse(item['createdAt'] as String);
      final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
      final quantity = (item['requestQuantity'] as num).toDouble();
      dailyTotals[dayOfWeek] = (dailyTotals[dayOfWeek] ?? 0) + quantity;
    }

    // Convert to list of FlSpot with proper day indices
    return List.generate(7, (index) {
      final dayOfWeek = index + 1; // 1-7 for Monday-Sunday
      final totalQuantity = dailyTotals[dayOfWeek] ?? 0;
      return FlSpot(index.toDouble(), totalQuantity);
    });
  }

  List<Map<String, dynamic>> _filterDataByTime(
    List<Map<String, dynamic>> forecast,
  ) {
    if (forecast.isEmpty) return [];

    final now = DateTime.now();
    final List<Map<String, dynamic>> filteredData = [];

    for (var item in forecast) {
      final createdAt = DateTime.parse(item['createdAt'] as String);
      
      switch (_selectedTimeFilter) {
        case 'Daily':
          // Filter for selected day of week in current month between 10:00 AM and 8:00 PM
          final selectedDayIndex = _getDayIndex(_selectedDayFilter);
          final selectedMonthIndex = _getMonthIndex(_selectedMonthFilter);
          if (createdAt.year == now.year &&
              createdAt.month == selectedMonthIndex &&
              createdAt.weekday == selectedDayIndex &&
              createdAt.hour >= 10 &&
              createdAt.hour < 20) {
            filteredData.add(item);
          }
          break;
          
        case 'Weekly':
          // Filter for selected week of current month (April)
          final selectedWeekNumber = int.parse(_selectedWeekFilter.split(' ')[1]);
          final selectedMonthIndex = _getMonthIndex(_selectedMonthFilter);
          if (_isInSelectedWeekOfMonth(createdAt, selectedWeekNumber, selectedMonthIndex, now.year)) {
            filteredData.add(item);
          }
          break;
          
        case 'Monthly':
          // Filter for selected month of current year
          final selectedMonthIndex = _getMonthIndex(_selectedMonthFilter);
          if (createdAt.year == now.year && createdAt.month == selectedMonthIndex) {
            filteredData.add(item);
          }
          break;
      }
    }

    return filteredData;
  }

  int _getDayIndex(String dayName) {
    switch (dayName) {
      case 'Monday': return 1;
      case 'Tuesday': return 2;
      case 'Wednesday': return 3;
      case 'Thursday': return 4;
      case 'Friday': return 5;
      case 'Saturday': return 6;
      case 'Sunday': return 7;
      default: return 1;
    }
  }

  int _getMonthIndex(String monthName) {
    switch (monthName) {
      case 'January': return 1;
      case 'February': return 2;
      case 'March': return 3;
      case 'April': return 4;
      default: return 1;
    }
  }

  bool _isInSelectedWeek(DateTime date, int weekNumber, DateTime now) {
    // Get the first day of the current month
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    // Calculate the start and end of the selected week
    final weekStart = firstDayOfMonth.add(Duration(days: (weekNumber - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    // Check if the date is within the selected week of the current month
    return date.year == now.year &&
           date.month == now.month &&
           date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
           date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isInSelectedWeekOfMonth(DateTime date, int weekNumber, int monthIndex, int year) {
    // Get first day of selected month
    final firstDayOfMonth = DateTime(year, monthIndex, 1);
    
    // Calculate start and end of the selected week within the specified month
    final weekStart = firstDayOfMonth.add(Duration(days: (weekNumber - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    // Check if the date is within the selected week of the specified month
    return date.year == year &&
           date.month == monthIndex &&
           date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
           date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  double _getBarChartMaxY() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return 275; // Max Y for Daily (250 + buffer)
      case 'Weekly':
        return 550; // Max Y for Weekly (500 + buffer)
      case 'Monthly':
        return 2400; // Max Y for Monthly (2200 + buffer)
      default:
        return 100; // Default max Y
    }
  }

  double _getBarChartInterval() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return 25; // Interval for Daily (0,25,50,75,100,125,150,175,200,225,250)
      case 'Weekly':
        return 50; // Interval for Weekly (0,50,100,150,200,250,300,350,400,450,500)
      case 'Monthly':
        return 200; // Interval for Monthly (0,200,400,600,800,1000,1200,1400,1600,1800,2000,2200)
      default:
        return 20; // Default interval
    }
  }

  String _getFilterSuffix() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return ' - $_selectedDayFilter';
      case 'Weekly':
        return ' - $_selectedWeekFilter';
      case 'Monthly':
        return ' - $_selectedMonthFilter';
      default:
        return '';
    }
  }

  List<BarChartGroupData> _getTopItemsData(
    List<Map<String, dynamic>> forecast,
  ) {
    // Apply time-based filtering first
    final timeFilteredData = _filterDataByTime(forecast);
    
    if (timeFilteredData.isEmpty) return [];

    // Group requests by item name and sum quantities
    final Map<String, double> itemTotals = {};

    for (var item in timeFilteredData) {
      final itemName = item['name'] as String;
      final quantity = (item['requestQuantity'] as num).toDouble();
      itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
    }

    // Sort by quantity (descending) and take top 10
    final sortedItems = itemTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sortedItems.take(10).toList();

    // Convert to BarChartGroupData
    return List.generate(topItems.length, (index) {
      final item = topItems[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.value,
            color: AppTheme.primaryColor,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _buildBarChartCard(List<Map<String, dynamic>> forecast) {
    if (forecast.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGrey.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No data available for chart',
            style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14),
          ),
        ),
      );
    }

    final barGroups = _getTopItemsData(forecast);

    // Get item names for labels using the same time-filtered data
    final timeFilteredData = _filterDataByTime(forecast);
    final Map<String, double> itemTotals = {};
    for (var item in timeFilteredData) {
      final itemName = item['name'] as String;
      final quantity = (item['requestQuantity'] as num).toDouble();
      itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
    }
    final sortedItems = itemTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(10).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGrey.withValues(alpha: 0.08),
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
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Top Requested Items - $_selectedTimeFilter${_getFilterSuffix()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              _buildCompactTimeFilterSelector(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Most Requested Ingredients in Kitchen ($_selectedTimeFilter${_getFilterSuffix()})',
            style: const TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 400,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getBarChartMaxY(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.darkGrey,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < topItems.length) {
                        final itemName = topItems[groupIndex].key;
                        final quantity = topItems[groupIndex].value.toInt();
                        return BarTooltipItem(
                          '$itemName\n$quantity units',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _getBarChartInterval(),
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 80,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < topItems.length) {
                          final itemName = topItems[index].key;
                          final displayName = itemName.length > 8
                              ? '${itemName.substring(0, 8)}...'
                              : itemName;
                          return Text(
                            displayName,
                            style: const TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: AppTheme.lightGrey.withValues(alpha: 0.3),
                  ),
                ),
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.white,
        automaticallyImplyLeading: false,
        title: const Text('Inventory Forecast'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Forecast',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showChart = !_showChart;
                _forecastFuture = _getForecastData();
              });
            },
            icon: Icon(_showChart ? Icons.list : Icons.show_chart),
            tooltip: _showChart ? 'Show List' : 'Show Chart',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            // Controls Section
            Container(
              margin: EdgeInsets.all(
                ResponsiveUtils.isMobile(context) ? 8 : 16,
              ),
              padding: EdgeInsets.all(
                ResponsiveUtils.isMobile(context) ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkGrey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ResponsiveUtils.isMobile(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCategorySelector(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCategorySelector(),
                          ],
                        ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _forecastFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading forecast: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    );
                  }

                  final forecast = snapshot.data ?? [];
                  var filteredForecast = forecast;

                  // Apply category filter first
                  if (_selectedCategory != 'All') {
                    filteredForecast = filteredForecast
                        .where((item) => item['category'] == _selectedCategory)
                        .toList();
                  }


                  if (filteredForecast.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.trending_up,
                            size: 64,
                            color: AppTheme.mediumGrey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No forecast data available',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adding more inventory or transaction data',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Show Chart View
                  if (_showChart) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Bar Chart Card
                          _buildBarChartCard(filteredForecast),
                        ],
                      ),
                    );
                  }

                  // Show List View
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredForecast.length,
                    itemBuilder: (context, index) {
                      final item = filteredForecast[index];
                      return _ForecastCard(
                        item: item,
                        periodDays: _getDaysFromPeriod(_selectedPeriod),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category Filter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Select Category',
            prefixIcon: const Icon(
              Icons.category,
              color: AppTheme.primaryColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.lightGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            filled: true,
            fillColor: AppTheme.backgroundColor,
          ),
          items: categories.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedCategory = value);
          },
        ),
      ],
    );
  }

  Widget _buildTimeFilterSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time Filter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: timeFilters.map((filter) {
              final isSelected = _selectedTimeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTimeFilter = filter;
                      _forecastFuture = _getForecastData();
                    });
                  },
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.darkGrey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.lightGrey,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTimeFilterSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Time Filter Dropdown
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            value: _selectedTimeFilter,
            decoration: InputDecoration(
              labelText: 'Period',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              filled: true,
              fillColor: AppTheme.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: timeFilters.map((filter) {
              return DropdownMenuItem(value: filter, child: Text(filter, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedTimeFilter = value;
                  _forecastFuture = _getForecastData();
                });
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Secondary Filter Dropdown
        _buildSecondaryFilterDropdown(),
      ],
    );
  }

  Widget _buildSecondaryFilterDropdown() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            value: _selectedDayFilter,
            decoration: InputDecoration(
              labelText: 'Day',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              filled: true,
              fillColor: AppTheme.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: dayFilters.map((day) {
              return DropdownMenuItem(value: day, child: Text(day, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDayFilter = value;
                  _forecastFuture = _getForecastData();
                });
              }
            },
          ),
        );
      case 'Weekly':
        return Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            value: _selectedWeekFilter,
            decoration: InputDecoration(
              labelText: 'Week',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              filled: true,
              fillColor: AppTheme.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: weekFilters.map((week) {
              return DropdownMenuItem(value: week, child: Text(week, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedWeekFilter = value;
                  _forecastFuture = _getForecastData();
                });
              }
            },
          ),
        );
      case 'Monthly':
        return Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            value: _selectedMonthFilter,
            decoration: InputDecoration(
              labelText: 'Month',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              filled: true,
              fillColor: AppTheme.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: monthFilters.map((month) {
              return DropdownMenuItem(value: month, child: Text(month, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMonthFilter = value;
                  _forecastFuture = _getForecastData();
                });
              }
            },
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int periodDays;

  const _ForecastCard({required this.item, required this.periodDays});

  @override
  Widget build(BuildContext context) {
    final riskColor = item['riskColor'] as Color;
    final riskIcon = item['riskIcon'] as IconData;
    final priority = item['priority'] as String;
    final currentStock = item['currentStock'] as int;
    final requestQuantity = item['requestQuantity'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with risk indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['category'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(riskIcon, color: riskColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      priority,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock Information Grid
          ResponsiveUtils.isMobile(context)
              ? Column(
                  children: [
                    _InfoCard(
                      title: 'Request Quantity',
                      value: '$requestQuantity ${item['unit']}',
                      icon: Icons.shopping_cart,
                      iconColor: AppTheme.warningOrange,
                    ),
                    const SizedBox(height: 8),
                    _InfoCard(
                      title: 'Current Stock',
                      value: '$currentStock ${item['unit']}',
                      icon: Icons.inventory_2,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        title: 'Current Stock',
                        value: '$currentStock ${item['unit']}',
                        icon: Icons.inventory_2,
                        iconColor: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        title: 'Request Quantity',
                        value: '$requestQuantity ${item['unit']}',
                        icon: Icons.shopping_cart,
                        iconColor: AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}
