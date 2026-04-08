import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminForecastPage extends StatefulWidget {
  const AdminForecastPage({super.key});

  @override
  State<AdminForecastPage> createState() => _AdminForecastPageState();
}

class _AdminForecastPageState extends State<AdminForecastPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _selectedPeriod = '7days';
  String _selectedCategory = 'All';
  String _selectedItemName = 'All';
  bool _showChart = true;
  late Future<List<Map<String, dynamic>>> _forecastFuture;

  final List<String> periods = ['7days', '30days', '90days'];
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
      final inventoryResponse = await Supabase.instance.client
          .from('inventory')
          .select()
          .order('name');

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

    final Map<String, Map<String, dynamic>> inventoryMap = {};
    for (var item in inventory) {
      inventoryMap[item['name'] as String] = item;
    }

    for (var transaction in transactions) {
      final itemName = transaction['item_name'] as String;
      final inventoryItem = inventoryMap[itemName];
      
      if (inventoryItem == null) {
        continue;
      }
      
      final currentStock = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
      final unit = transaction['unit'] as String? ?? 'pcs';
      final requestQuantity = (transaction['quantity_needed'] as num?)?.toInt() ?? 0;
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
    
    final Map<int, double> dailyTotals = {
      1: 0.0,
      2: 0.0,
      3: 0.0,
      4: 0.0,
      5: 0.0,
      6: 0.0,
      7: 0.0,
    };
    
    for (var item in forecast) {
      final date = DateTime.parse(item['createdAt'] as String);
      final dayOfWeek = date.weekday;
      final quantity = (item['requestQuantity'] as num).toDouble();
      dailyTotals[dayOfWeek] = (dailyTotals[dayOfWeek] ?? 0) + quantity;
    }

    return List.generate(7, (index) {
      final dayOfWeek = index + 1;
      final totalQuantity = dailyTotals[dayOfWeek] ?? 0;
      return FlSpot(index.toDouble(), totalQuantity);
    });
  }

  List<BarChartGroupData> _getTopItemsData(List<Map<String, dynamic>> forecast) {
    if (forecast.isEmpty) return [];
    
    final Map<String, double> itemTotals = {};
    
    for (var item in forecast) {
      final itemName = item['name'] as String;
      final quantity = (item['requestQuantity'] as num).toDouble();
      itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
    }

    final sortedItems = itemTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topItems = sortedItems.take(10).toList();
    
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
            style: TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final barGroups = _getTopItemsData(forecast);
    
    final Map<String, double> itemTotals = {};
    for (var item in forecast) {
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
            children: [
              const Icon(Icons.bar_chart, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Top Requested Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Most Requested Ingredients in Kitchen',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: barGroups.isNotEmpty 
                    ? barGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2
                    : 100,
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
                      interval: 20,
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
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.3)),
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

  Widget _buildLineChartCard(List<Map<String, dynamic>> forecast) {
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
            style: TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final spots = _getChartData(forecast);

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
            children: [
              const Icon(Icons.show_chart, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Quantity Request by Day of Week',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kitchen Requests',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.lightGrey.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: AppTheme.lightGrey.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
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
                      interval: 1,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final dayIndex = value.toInt();
                        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (dayIndex >= 0 && dayIndex < dayNames.length) {
                          return Text(
                            dayNames[dayIndex],
                            style: const TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.3)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
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
      backgroundColor: const Color(0xFFF1F5F9),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
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
                            _buildPeriodSelector(),
                            const SizedBox(height: 16),
                            _buildCategorySelector(),
                            const SizedBox(height: 16),
                            _buildItemNameSelector(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildPeriodSelector()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildCategorySelector()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildItemNameSelector(),
                          ],
                        ),
                ],
              ),
            ),

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
                  
                  if (_selectedCategory != 'All') {
                    filteredForecast = filteredForecast
                        .where((item) => item['category'] == _selectedCategory)
                        .toList();
                  }
                  
                  if (_selectedItemName != 'All') {
                    filteredForecast = filteredForecast
                        .where((item) => item['name'] == _selectedItemName)
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

                  if (_showChart) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildBarChartCard(filteredForecast),
                          const SizedBox(height: 16),
                          _buildLineChartCard(filteredForecast),
                        ],
                      ),
                    );
                  }

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

  String _getPeriodLabel(String period) {
    switch (period) {
      case '7days':
        return 'Last 7 Days';
      case '30days':
        return 'Last 30 Days';
      case '90days':
        return 'Last 90 Days';
      default:
        return 'Last 7 Days';
    }
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis Period',
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
            children: periods.map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_getPeriodLabel(period)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      _forecastFuture = _getForecastData();
                    });
                  },
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.darkGrey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.lightGrey,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
            prefixIcon: const Icon(Icons.category, color: AppTheme.primaryColor),
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

  Widget _buildItemNameSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Name Filter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedItemName,
          decoration: InputDecoration(
            labelText: 'Select Item',
            prefixIcon: const Icon(Icons.inventory, color: AppTheme.primaryColor),
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
          items: itemNames.map((itemName) {
            return DropdownMenuItem(value: itemName, child: Text(itemName));
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedItemName = value);
          },
        ),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int periodDays;

  const _ForecastCard({
    required this.item,
    required this.periodDays,
  });

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
