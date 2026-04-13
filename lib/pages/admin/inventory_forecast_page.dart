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
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'Daily'; // New time filter for Daily/Weekly/Monthly
  String _selectedDailyMonth = 'January'; // Month for Daily filtering
  String _selectedDailyDay = '1'; // Day for Daily filtering (1-31)
  String _selectedWeeklyMonth = 'January'; // Month for Weekly filtering
  String _selectedWeekFilter = 'Week 1'; // Week number for Weekly filtering (Week 1-4)
  String _selectedMonthFilter = 'January'; // Secondary filter for Monthly (January-April)
  String _selectedYearFilter = DateTime.now().year.toString(); // Secondary filter for Annually
  bool _showChart = true; // Toggle between chart and list
  late Future<List<Map<String, dynamic>>> _forecastFuture;

  final List<String> timeFilters = ['Daily', 'Weekly', 'Monthly', 'Annually'];
  final List<String> dayFilters = List.generate(31, (index) => (index + 1).toString()); // Days 1-31 for Daily filtering
  final List<String> weekFilters = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
  final List<String> monthFilters = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> yearFilters = List.generate(2031 - DateTime.now().year + 1, (index) => (DateTime.now().year + index).toString());
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

      // Get approved kitchen requests for the last 90 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

      final transactionsResponse = await Supabase.instance.client
          .from('kitchen_requests')
          .select()
          .eq('status', 'Approved')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: false);

      final inventory = inventoryResponse;
      final transactions = transactionsResponse;


      return _calculateForecast(inventory, transactions);
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _calculateForecast(
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> transactions,
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
          // Filter for specific date (month + day) in current year between 10:00 AM and 8:00 PM
          final selectedMonthIndex = _getMonthIndex(_selectedDailyMonth);
          final selectedDay = int.parse(_selectedDailyDay);
          if (createdAt.year == now.year &&
              createdAt.month == selectedMonthIndex &&
              createdAt.day == selectedDay &&
              createdAt.hour >= 10 &&
              createdAt.hour < 20) {
            filteredData.add(item);
          }
          break;
          
        case 'Weekly':
          // Filter for selected week of specific month in current year
          final selectedWeekNumber = int.parse(_selectedWeekFilter.split(' ')[1]);
          final selectedMonthIndex = _getMonthIndex(_selectedWeeklyMonth);
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
          
        case 'Annually':
          // Filter for selected year
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
      case 'Annually':
        return 30000; // Max Y for Annually (28000 + buffer)
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
      case 'Annually':
        return 2000; // Interval for Annually (0,2000,4000,6000,8000,10000,12000,14000,16000,18000,20000,22000,24000,26000,28000)
      default:
        return 20; // Default interval
    }
  }

  String _getFilterSuffix() {
    switch (_selectedTimeFilter) {
      case 'Daily':
        return ' - $_selectedDailyMonth $_selectedDailyDay';
      case 'Weekly':
        return ' - $_selectedWeeklyMonth $_selectedWeekFilter';
      case 'Monthly':
        return ' - $_selectedMonthFilter';
      case 'Annually':
        return ' - $_selectedYearFilter';
      default:
        return '';
    }
  }

  Map<String, dynamic> _getTopItemsData(
    List<Map<String, dynamic>> forecast,
  ) {
    // Apply time-based filtering first
    final timeFilteredData = _filterDataByTime(forecast);
    
    if (timeFilteredData.isEmpty) {
      return {
        'barGroups': <BarChartGroupData>[],
        'topItems': <MapEntry<String, double>>[]
      };
    }

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
    final barGroups = List.generate(topItems.length, (index) {
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

    return {
      'barGroups': barGroups,
      'topItems': topItems,
    };
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

    final chartData = _getTopItemsData(forecast);
    final barGroups = chartData['barGroups'] as List<BarChartGroupData>;
    final topItems = chartData['topItems'] as List<MapEntry<String, double>>;

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategorySelector(),
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

  
  Widget _buildCompactTimeFilterSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Time Filter Dropdown
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
          initialValue: _selectedTimeFilter,
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month dropdown for Daily
            Container(
              constraints: const BoxConstraints(maxWidth: 110),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedDailyMonth,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: monthFilters.map((month) {
                  return DropdownMenuItem(value: month, child: Text(month, style: const TextStyle(fontSize: 11)));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDailyMonth = value;
                      _forecastFuture = _getForecastData();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // Day dropdown for Daily
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedDailyDay,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: dayFilters.map((day) {
                  return DropdownMenuItem(value: day, child: Text(day, style: const TextStyle(fontSize: 11)));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDailyDay = value;
                      _forecastFuture = _getForecastData();
                    });
                  }
                },
              ),
            ),
          ],
        );
      case 'Weekly':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month dropdown for Weekly
            Container(
              constraints: const BoxConstraints(maxWidth: 110),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedWeeklyMonth,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: monthFilters.map((month) {
                  return DropdownMenuItem(value: month, child: Text(month, style: const TextStyle(fontSize: 11)));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedWeeklyMonth = value;
                      _forecastFuture = _getForecastData();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // Week dropdown for Weekly
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedWeekFilter,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: weekFilters.map((week) {
                  return DropdownMenuItem(value: week, child: Text(week, style: const TextStyle(fontSize: 11)));
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
            ),
          ],
        );
      case 'Monthly':
        return Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedMonthFilter,
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
      case 'Annually':
        return Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedYearFilter,
            decoration: InputDecoration(
              labelText: 'Year',
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
            items: yearFilters.map((year) {
              return DropdownMenuItem(value: year, child: Text(year, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedYearFilter = value;
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

  const _ForecastCard({required this.item});

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
