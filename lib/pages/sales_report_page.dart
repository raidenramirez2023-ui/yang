import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  String selectedPeriod = 'Today';
  String selectedChart = 'Revenue';
  
  // Sample data for demonstration
  final List<Map<String, dynamic>> salesData = [
    {'date': 'Mon', 'revenue': 4500, 'orders': 45},
    {'date': 'Tue', 'revenue': 5200, 'orders': 52},
    {'date': 'Wed', 'revenue': 3800, 'orders': 38},
    {'date': 'Thu', 'revenue': 6100, 'orders': 61},
    {'date': 'Fri', 'revenue': 7200, 'orders': 72},
    {'date': 'Sat', 'revenue': 8500, 'orders': 85},
    {'date': 'Sun', 'revenue': 6800, 'orders': 68},
  ];

  final List<Map<String, dynamic>> topProducts = [
    {'name': 'Yang Chow', 'sales': 156, 'revenue': 31200},
    {'name': 'Sweet & Sour Pork', 'sales': 98, 'revenue': 17640},
    {'name': 'Fried Rice', 'sales': 87, 'revenue': 10440},
    {'name': 'Beef Broccoli', 'sales': 76, 'revenue': 16720},
    {'name': 'Chopsuey', 'sales': 65, 'revenue': 9750},
  ];

  final List<Map<String, dynamic>> hourlyData = [
    {'hour': '8AM', 'revenue': 800},
    {'hour': '10AM', 'revenue': 1200},
    {'hour': '12PM', 'revenue': 2800},
    {'hour': '2PM', 'revenue': 2400},
    {'hour': '4PM', 'revenue': 1800},
    {'hour': '6PM', 'revenue': 3200},
    {'hour': '8PM', 'revenue': 2100},
    {'hour': '10PM', 'revenue': 900},
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 800 && size.width <= 1200;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Reports',
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor your restaurant performance',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // Period selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPeriod,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        items: ['Today', 'This Week', 'This Month', 'This Year'].map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text(period),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPeriod = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Summary Cards
              _buildSummaryCards(isDesktop, isTablet),
              
              const SizedBox(height: 24),
              
              // Charts Section
              Row(
                children: [
                  // Chart type selector
                  Expanded(
                    flex: isDesktop ? 1 : 2,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: ['Revenue', 'Orders', 'Products'].map((type) {
                          final isSelected = selectedChart == type;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedChart = type;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.red.shade600 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey.shade700,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: isDesktop ? 14 : 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Main Chart
              _buildMainChart(isDesktop, isTablet),
              
              const SizedBox(height: 24),
              
              // Secondary Charts Row
              if (isDesktop || isTablet)
                Row(
                  children: [
                    Expanded(child: _buildHourlyChart(isDesktop)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTopProductsChart(isDesktop)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildHourlyChart(isDesktop),
                    const SizedBox(height: 16),
                    _buildTopProductsChart(isDesktop),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // Top Products Table
              _buildTopProductsTable(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDesktop, bool isTablet) {
    final cards = [
      {
        'title': 'Total Revenue',
        'value': '₱42,100',
        'change': '+12.5%',
        'isPositive': true,
        'icon': Icons.attach_money,
        'color': Colors.green,
      },
      {
        'title': 'Total Orders',
        'value': '421',
        'change': '+8.2%',
        'isPositive': true,
        'icon': Icons.shopping_cart,
        'color': Colors.blue,
      },
      {
        'title': 'Avg. Order Value',
        'value': '₱100',
        'change': '+3.1%',
        'isPositive': true,
        'icon': Icons.receipt_long,
        'color': Colors.orange,
      },
      {
        'title': 'Customers',
        'value': '285',
        'change': '-2.4%',
        'isPositive': false,
        'icon': Icons.people,
        'color': Colors.purple,
      },
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((card) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildSummaryCard(card, isDesktop),
          ),
        )).toList(),
      );
    } else if (isTablet) {
      return Row(
        children: [
          Expanded(child: _buildSummaryCard(cards[0], isDesktop)),
          const SizedBox(width: 16),
          Expanded(child: _buildSummaryCard(cards[1], isDesktop)),
        ],
      );
    } else {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSummaryCard(card, isDesktop),
        )).toList(),
      );
    }
  }

  Widget _buildSummaryCard(Map<String, dynamic> card, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (card['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  card['icon'] as IconData,
                  color: card['color'] as Color,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (card['isPositive'] as bool ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      card['isPositive'] as bool ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: card['isPositive'] as bool ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      card['change'] as String,
                      style: TextStyle(
                        color: card['isPositive'] as bool ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            card['title'] as String,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card['value'] as String,
            style: TextStyle(
              fontSize: isDesktop ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainChart(bool isDesktop, bool isTablet) {
    return Container(
      height: isDesktop ? 400 : 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedChart} Overview',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: selectedChart == 'Revenue'
                ? _buildRevenueChart()
                : selectedChart == 'Orders'
                    ? _buildOrdersChart()
                    : _buildProductsChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1000,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₱${(value / 1000).toInt()}k',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < salesData.length) {
                  return Text(
                    salesData[index]['date'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: salesData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), (entry.value['revenue'] as double));
            }).toList(),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.orange],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.3),
                  Colors.orange.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersChart() {
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < salesData.length) {
                  return Text(
                    salesData[index]['date'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: salesData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value['orders'] as double,
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductsChart() {
    return PieChart(
      PieChartData(
        sections: topProducts.take(5).toList().asMap().entries.map((entry) {
          final product = entry.value;
          final color = [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
          ][entry.key % 5];
          
          return PieChartSectionData(
            value: (product['sales'] as double).toDouble(),
            title: '${product['name']}\n${product['sales']}',
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            color: color,
            radius: 80,
            titlePositionPercentageOffset: 0.6,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        centerSpaceColor: Colors.white,
      ),
    );
  }

  Widget _buildHourlyChart(bool isDesktop) {
    return Container(
      height: isDesktop ? 300 : 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly Revenue',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < hourlyData.length) {
                          return Text(
                            hourlyData[index]['hour'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: hourlyData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['revenue'] as double,
                        color: Colors.green,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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

  Widget _buildTopProductsChart(bool isDesktop) {
    return Container(
      height: isDesktop ? 300 : 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Products',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                final product = topProducts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: [
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                          ][index % 5].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: [
                                Colors.red,
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                              ][index % 5],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${product['sales']} sold',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${(product['revenue'] as int).toString()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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

  Widget _buildTopProductsTable(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Product Performance',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _buildTableCell('Product Name', isHeader: true, isDesktop: isDesktop),
                  _buildTableCell('Units Sold', isHeader: true, isDesktop: isDesktop),
                  _buildTableCell('Revenue', isHeader: true, isDesktop: isDesktop),
                  _buildTableCell('Avg. Price', isHeader: true, isDesktop: isDesktop),
                ],
              ),
              // Data rows
              ...topProducts.map((product) {
                return TableRow(
                  children: [
                    _buildTableCell(product['name'] as String, isDesktop: isDesktop),
                    _buildTableCell(product['sales'].toString(), isDesktop: isDesktop),
                    _buildTableCell('₱${(product['revenue'] as int).toString()}', isDesktop: isDesktop),
                    _buildTableCell('₱${((product['revenue'] as int) / (product['sales'] as int)).toStringAsFixed(2)}', isDesktop: isDesktop),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isDesktop ? 14 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey.shade700 : Colors.grey.shade600,
        ),
      ),
    );
  }
}
