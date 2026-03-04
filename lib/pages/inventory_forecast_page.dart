import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryForecastPage extends StatefulWidget {
  const InventoryForecastPage({super.key});

  @override
  State<InventoryForecastPage> createState() => _InventoryForecastPageState();
}

class _InventoryForecastPageState extends State<InventoryForecastPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _selectedPeriod = '7days';
  String _selectedCategory = 'All';

  final List<String> periods = ['7days', '30days', '90days'];
  final List<String> categories = [
    'All',
    'Perishable Ingredients',
    'Non-perishable Ingredients',
    'Beverages',
    'Condiments',
    'Packaging',
  ];

  @override
  void initState() {
    super.initState();
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

  Future<List<Map<String, dynamic>>> _getForecastData() async {
    try {
      // Get current inventory
      final inventoryResponse = await Supabase.instance.client
          .from('inventory')
          .select()
          .order('name');

      // Get outgoing transactions for the selected period
      final days = _getDaysFromPeriod(_selectedPeriod);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final transactionsResponse = await Supabase.instance.client
          .from('stock_transactions')
          .select()
          .eq('transaction_type', 'outgoing')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: false);

      final inventory = inventoryResponse ?? [];
      final transactions = transactionsResponse ?? [];

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

    for (var item in inventory) {
      final itemName = item['name'] as String;
      final currentStock = (item['quantity'] as num?)?.toInt() ?? 0;
      final unit = item['unit'] as String? ?? 'pcs';

      // Calculate usage from transactions
      final itemTransactions = transactions
          .where((t) => t['item_name'] == itemName)
          .toList();

      double totalUsage = 0;
      for (var transaction in itemTransactions) {
        totalUsage += (transaction['quantity'] as num?)?.toDouble() ?? 0;
      }

      // Calculate daily average usage
      double dailyUsage = totalUsage / periodDays;
      
      // Calculate days until out of stock
      int daysUntilEmpty = dailyUsage > 0 
          ? (currentStock / dailyUsage).round()
          : 999; // No usage = won't run out

      // Calculate risk level
      String riskLevel = _getRiskLevel(daysUntilEmpty, currentStock);
      Color riskColor = _getRiskColor(daysUntilEmpty, currentStock);
      IconData riskIcon = _getRiskIcon(daysUntilEmpty, currentStock);

      // Calculate recommended reorder quantity
      int recommendedOrder = _calculateRecommendedOrder(dailyUsage, currentStock, daysUntilEmpty);

      forecast.add({
        'name': itemName,
        'category': item['category'] ?? 'Uncategorized',
        'currentStock': currentStock,
        'unit': unit,
        'dailyUsage': dailyUsage.toStringAsFixed(2),
        'totalUsage': totalUsage.toInt(),
        'daysUntilEmpty': daysUntilEmpty,
        'riskLevel': riskLevel,
        'riskColor': riskColor,
        'riskIcon': riskIcon,
        'recommendedOrder': recommendedOrder,
        'lastUsage': itemTransactions.isNotEmpty ? itemTransactions.first['created_at'] : null,
      });
    }

    // Sort by risk (most critical first)
    forecast.sort((a, b) => (a['daysUntilEmpty'] as int).compareTo(b['daysUntilEmpty'] as int));
    
    return forecast;
  }

  String _getRiskLevel(int daysUntilEmpty, int currentStock) {
    if (currentStock == 0) return 'OUT OF STOCK';
    if (daysUntilEmpty <= 3) return 'CRITICAL';
    if (daysUntilEmpty <= 7) return 'HIGH RISK';
    if (daysUntilEmpty <= 14) return 'MODERATE RISK';
    return 'LOW RISK';
  }

  Color _getRiskColor(int daysUntilEmpty, int currentStock) {
    if (currentStock == 0) return AppTheme.errorRed;
    if (daysUntilEmpty <= 3) return AppTheme.errorRed;
    if (daysUntilEmpty <= 7) return AppTheme.warningOrange;
    if (daysUntilEmpty <= 14) return AppTheme.infoBlue;
    return AppTheme.successGreen;
  }

  IconData _getRiskIcon(int daysUntilEmpty, int currentStock) {
    if (currentStock == 0) return Icons.error_rounded;
    if (daysUntilEmpty <= 3) return Icons.warning_rounded;
    if (daysUntilEmpty <= 7) return Icons.priority_high_rounded;
    if (daysUntilEmpty <= 14) return Icons.info_rounded;
    return Icons.check_circle_rounded;
  }

  int _calculateRecommendedOrder(double dailyUsage, int currentStock, int daysUntilEmpty) {
    if (dailyUsage == 0) return 0;
    
    // Recommend 30 days supply + safety stock (25%)
    double thirtyDaySupply = dailyUsage * 30;
    double safetyStock = thirtyDaySupply * 0.25;
    double totalNeeded = thirtyDaySupply + safetyStock;
    
    return (totalNeeded - currentStock).round().clamp(0, 999999);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: AppTheme.white,
        title: const Text('Inventory Forecast'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Forecast',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            // Controls Section
            Container(
              margin: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 16),
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 12 : 16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkGrey.withOpacity(0.1),
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
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _buildPeriodSelector()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCategorySelector()),
                          ],
                        ),
                ],
              ),
            ),

            // Forecast Results
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getForecastData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
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
                  final filteredForecast = _selectedCategory == 'All'
                      ? forecast
                      : forecast.where((item) => item['category'] == _selectedCategory).toList();

                  if (filteredForecast.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up, size: 64, color: AppTheme.mediumGrey),
                          const SizedBox(height: 16),
                          Text(
                            'No forecast data available',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
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
        Text(
          'Analysis Period',
          style: const TextStyle(
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
                    setState(() => _selectedPeriod = period);
                  },
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.primaryRed.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryRed,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryRed : AppTheme.darkGrey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryRed : AppTheme.lightGrey,
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
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Select Category',
            prefixIcon: const Icon(Icons.category, color: AppTheme.primaryRed),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.lightGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryRed),
            ),
            filled: true,
            fillColor: AppTheme.backgroundColor,
          ),
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedCategory = value);
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
    super.key,
    required this.item,
    required this.periodDays,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = item['riskColor'] as Color;
    final riskIcon = item['riskIcon'] as IconData;
    final riskLevel = item['riskLevel'] as String;
    final daysUntilEmpty = item['daysUntilEmpty'] as int;
    final currentStock = item['currentStock'] as int;
    final dailyUsage = double.tryParse(item['dailyUsage'] as String) ?? 0;
    final recommendedOrder = item['recommendedOrder'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: riskColor.withOpacity(0.3),
          width: 2,
        ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(riskIcon, color: riskColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      riskLevel,
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
                      title: 'Current Stock',
                      value: '$currentStock ${item['unit']}',
                      icon: Icons.inventory_2,
                      iconColor: AppTheme.primaryRed,
                    ),
                    const SizedBox(height: 8),
                    _InfoCard(
                      title: 'Daily Usage (Average)',
                      value: '${dailyUsage.toStringAsFixed(1)} ${item['unit']}/day',
                      icon: Icons.trending_down,
                      iconColor: AppTheme.warningOrange,
                    ),
                    const SizedBox(height: 8),
                    _InfoCard(
                      title: 'Days Until Empty',
                      value: daysUntilEmpty == 999 ? 'No usage' : '$daysUntilEmpty days',
                      icon: Icons.schedule,
                      iconColor: riskColor,
                    ),
                    const SizedBox(height: 8),
                    _InfoCard(
                      title: 'Total Usage (Last $periodDays days)',
                      value: '${item['totalUsage']} ${item['unit']}',
                      icon: Icons.history,
                      iconColor: AppTheme.infoBlue,
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
                        iconColor: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        title: 'Daily Usage (Average)',
                        value: '${dailyUsage.toStringAsFixed(1)} ${item['unit']}/day',
                        icon: Icons.trending_down,
                        iconColor: AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          if (!ResponsiveUtils.isMobile(context))
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    title: 'Days Until Empty',
                    value: daysUntilEmpty == 999 ? 'No usage' : '$daysUntilEmpty days',
                    icon: Icons.schedule,
                    iconColor: riskColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    title: 'Total Usage (Last $periodDays days)',
                    value: '${item['totalUsage']} ${item['unit']}',
                    icon: Icons.history,
                    iconColor: AppTheme.infoBlue,
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
                style: TextStyle(
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
