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

  final List<Color> chartColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isDesktop = size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER (fixed for mobile)
              isMobile ? _mobileHeader() : _desktopHeader(),

              const SizedBox(height: 24),

              /// SUMMARY
              _buildSummaryCards(isDesktop, isTablet),

              const SizedBox(height: 24),

              /// CHART SWITCHER
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  children: [
                    Container(
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
                              onTap: () => setState(() => selectedChart = type),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.red.shade600
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// MAIN CHART
              _buildMainChart(isDesktop, isTablet),

              const SizedBox(height: 24),

              /// SECONDARY CHARTS
              isDesktop
                  ? Row(
                      children: [
                        Expanded(child: _buildHourlyChart(isDesktop)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTopProductsChart(isDesktop)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildHourlyChart(isDesktop),
                        const SizedBox(height: 16),
                        _buildTopProductsChart(isDesktop),
                      ],
                    ),

              const SizedBox(height: 24),

              /// TABLE
              _buildTopProductsTable(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- HEADER ----------------
  Widget _desktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sales Reports',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Monitor your restaurant performance',
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
        _periodDropdown(),
      ],
    );
  }

  Widget _mobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sales Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Monitor your restaurant performance',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        _periodDropdown(),
      ],
    );
  }

  Widget _periodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedPeriod,
          items: ['Today', 'This Week', 'This Month', 'This Year']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => selectedPeriod = v!),
        ),
      ),
    );
  }

  /// ---------------- SUMMARY ----------------
  Widget _buildSummaryCards(bool isDesktop, bool isTablet) {
    final cards = [
      _summary('Total Revenue', '₱42,100', Icons.attach_money, Colors.green),
      _summary('Total Orders', '421', Icons.shopping_cart, Colors.blue),
      _summary('Avg Order', '₱100', Icons.receipt_long, Colors.orange),
      _summary('Customers', '285', Icons.people, Colors.purple),
    ];

    if (isDesktop) {
      return Row(children: cards.map((c) => Expanded(child: c)).toList());
    }

    return Column(children: cards);
  }

  Widget _summary(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ])
        ],
      ),
    );
  }

  /// ---------------- CHARTS ----------------
  Widget _buildMainChart(bool isDesktop, bool isTablet) {
    return SizedBox(
      height: isDesktop ? 400 : 280,
      child: selectedChart == 'Revenue'
          ? _buildRevenueChart()
          : selectedChart == 'Orders'
              ? _buildOrdersChart()
              : _buildProductsChart(),
    );
  }

  Widget _buildRevenueChart() => LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: salesData
                  .asMap()
                  .entries
                  .map((e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['revenue'] as int).toDouble()))
                  .toList(),
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
            )
          ],
        ),
      );

  Widget _buildOrdersChart() => BarChart(
        BarChartData(
          barGroups: salesData
              .asMap()
              .entries
              .map((e) => BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                        toY: (e.value['orders'] as int).toDouble(),
                        color: Colors.blue)
                  ]))
              .toList(),
        ),
      );

  Widget _buildProductsChart() => PieChart(
        PieChartData(
          sections: topProducts
              .asMap()
              .entries
              .map((e) => PieChartSectionData(
                    value: (e.value['sales'] as int).toDouble(),
                    title: e.value['name'],
                    color: chartColors[e.key % chartColors.length],
                  ))
              .toList(),
        ),
      );

  Widget _buildHourlyChart(bool isDesktop) =>
      SizedBox(height: isDesktop ? 300 : 250, child: _buildOrdersChart());

  Widget _buildTopProductsChart(bool isDesktop) =>
      SizedBox(height: isDesktop ? 300 : 250, child: _buildProductsChart());

  /// ---------------- TABLE ----------------
  Widget _buildTopProductsTable(bool isDesktop) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Sales')),
          DataColumn(label: Text('Revenue')),
        ],
        rows: topProducts
            .map((p) => DataRow(cells: [
                  DataCell(Text(p['name'])),
                  DataCell(Text('${p['sales']}')),
                  DataCell(Text('₱${p['revenue']}')),
                ]))
            .toList(),
      ),
    );
  }
}
