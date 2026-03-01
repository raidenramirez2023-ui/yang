import 'dart:math';
import 'package:flutter/material.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage>
    with TickerProviderStateMixin {
  String selectedPeriod = 'Daily';
  String selectedYear = '2026'; // For monthly view
  final Random _rand = Random(10);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _cardAnimationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animationController.forward();
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  /// ================= REALISTIC SALES DATA =================
  Map<String, int> getSalesSummary() {
    if (selectedPeriod == 'Daily') {
      final revenue = 35000 + _rand.nextInt(5000); // 30k–40k
      final orders = (revenue / 400).round(); // Average order ₱400

      return {
        'revenue': revenue,
        'orders': orders,
        'customers': orders, // 1 customer per order
      };
    }

    if (selectedPeriod == 'Weekly') {
      final revenue = 200000;
      final orders = (revenue / 400).round();

      return {
        'revenue': revenue,
        'orders': orders,
        'customers': orders,
      };
    }

    // Monthly
    if (selectedPeriod == 'Monthly') {
      final revenue = 1050000 + _rand.nextInt(150000); // 900k–1.2M
      final orders = (revenue / 400).round();

      return {
        'revenue': revenue,
        'orders': orders,
        'customers': orders,
      };
    }

    // Annual
    final revenue = 10850000 + _rand.nextInt(1500000); // 9.7M–12M
    final orders = (revenue / 400).round();

    return {
      'revenue': revenue,
      'orders': orders,
      'customers': orders,
    };
  }

  /// ================= CHART DATA =================
  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(2)}m';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(0)}k';
    } else {
      return '₱${amount.toStringAsFixed(0)}';
    }
  }

  List<double> getChartData() {
    if (selectedPeriod == 'Daily') {
      return [32000, 35000, 33000, 38000, 36000, 39000, 37000];
    } else if (selectedPeriod == 'Weekly') {
      return [180000, 195000, 188000, 205000, 198000, 210000, 200000];
    } else if (selectedPeriod == 'Monthly') {
      // Different data for each year
      if (selectedYear == '2016') {
        return [850000, 880000, 820000, 900000, 870000, 920000, 950000, 980000, 910000, 940000, 970000, 970000];
      } else if (selectedYear == '2017') {
        return [920000, 950000, 890000, 970000, 940000, 990000, 1020000, 1050000, 980000, 1010000, 1040000, 1020000];
      } else if (selectedYear == '2018') {
        return [880000, 910000, 850000, 930000, 900000, 950000, 980000, 1010000, 940000, 970000, 1000000, 980000];
      } else if (selectedYear == '2019') {
        return [950000, 980000, 920000, 1000000, 970000, 1020000, 1050000, 1080000, 1010000, 1040000, 1070000, 1050000];
      } else if (selectedYear == '2020') {
        return [910000, 940000, 880000, 960000, 930000, 980000, 1010000, 1040000, 970000, 1000000, 1030000, 1010000];
      } else if (selectedYear == '2021') {
        return [980000, 1010000, 950000, 1030000, 1000000, 1050000, 1080000, 1110000, 1040000, 1070000, 1100000, 1080000];
      } else if (selectedYear == '2022') {
        return [1000000, 1030000, 970000, 1050000, 1020000, 1070000, 1100000, 1130000, 1060000, 1090000, 1120000, 1100000];
      } else if (selectedYear == '2023') {
        return [1050000, 1080000, 1020000, 1100000, 1070000, 1120000, 1150000, 1180000, 1110000, 1140000, 1170000, 1150000];
      } else if (selectedYear == '2024') {
        return [1080000, 1110000, 1050000, 1130000, 1100000, 1150000, 1180000, 1210000, 1140000, 1170000, 1200000, 1180000];
      } else if (selectedYear == '2025') {
        return [1100000, 1130000, 1070000, 1150000, 1120000, 1170000, 1200000, 1230000, 1160000, 1190000, 1220000, 1250000];
      } else { // 2026 - show all months but Apr-Dec are blank (future months)
        return [1150000, 1180000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      }
    } else {
      // Annual - 2016 to current year (2026)
      return [
        9700000, // 2016
        10200000, // 2017
        9800000, // 2018
        10500000, // 2019
        10100000, // 2020
        10800000, // 2021
        11000000, // 2022
        11500000, // 2023
        11800000, // 2024
        12000000, // 2025
        12500000, // 2026 (projected)
      ];
    }
  }

  List<String> getChartLabels() {
    if (selectedPeriod == 'Daily') {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (selectedPeriod == 'Weekly') {
      return ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7'];
    } else if (selectedPeriod == 'Monthly') {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    } else {
      // Annual - 2016 to current year (2026)
      return ['2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final data = getSalesSummary();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 24),
                _summaryCards(isDesktop, data),
                const SizedBox(height: 24),
                _chartCard(),
                const SizedBox(height: 24),
                _insightsCard(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ================= HEADER =================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Report',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your business performance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Year selector (only show for Monthly)
                if (selectedPeriod == 'Monthly')
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String>(
                        value: selectedYear,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                        items: ['2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              selectedYear = v;
                              _cardAnimationController.reset();
                              _cardAnimationController.forward();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                // Period selector
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                      items: const ['Daily', 'Weekly', 'Monthly', 'Annually']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            selectedPeriod = v;
                            _cardAnimationController.reset();
                            _cardAnimationController.forward();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ================= SUMMARY =================
  Widget _summaryCards(bool isDesktop, Map<String, int> data) {
    final cards = [
      _summaryCard(
        'Total Revenue',
        '₱${data['revenue']}',
        Icons.trending_up,
        const Color(0xFF10B981),
        '+12.5%',
      ),
      _summaryCard(
        'Total Orders',
        '${data['orders']}',
        Icons.shopping_cart,
        const Color(0xFF3B82F6),
        '+8.2%',
      ),
      _summaryCard(
        'Avg Order',
        '₱${(data['revenue']! / data['orders']!).round()}',
        Icons.receipt_long,
        const Color(0xFFF59E0B),
        '+3.1%',
      ),
      _summaryCard(
        'Customers',
        '${data['customers']}',
        Icons.people,
        const Color(0xFF8B5CF6),
        '+15.7%',
      ),
    ];

    return isDesktop
        ? Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: c,
                      ),
                    ))
                .toList(),
          )
        : Column(children: cards);
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color, String growth) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _cardAnimationController.value)),
          child: FadeTransition(
            opacity: _cardAnimationController,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          growth,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ================= CHART CARD =================
  Widget _chartCard() {
    final chartData = getChartData();
    final labels = getChartLabels();
    final maxValue = chartData.reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_chart,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Revenue Analytics - $selectedPeriod${selectedPeriod == 'Monthly' ? ' ($selectedYear)' : ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Simple bar chart using Container
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(chartData.length, (index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: (chartData[index] / maxValue) * 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF1D4ED8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(chartData[index]),
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('Peak', _formatCurrency(maxValue), Icons.arrow_upward, Colors.green),
              _summaryItem('Average', _formatCurrency(chartData.reduce((a, b) => a + b) / chartData.length), Icons.equalizer, Colors.blue),
              _summaryItem('Low', _formatCurrency(chartData.reduce((a, b) => a < b ? a : b)), Icons.arrow_downward, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ================= INSIGHTS CARD =================
  Widget _insightsCard(Map<String, int> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Business Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your ${selectedPeriod.toLowerCase()} performance shows strong growth with a ${(selectedPeriod == 'Daily' ? '12.5%' : selectedPeriod == 'Weekly' ? '15.2%' : selectedPeriod == 'Monthly' ? '18.7%' : '22.3%')} increase in revenue.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top performing period: ${selectedPeriod}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}