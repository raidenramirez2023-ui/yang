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
      final orders = revenue ~/ 100;

      return {
        'revenue': revenue,
        'orders': orders,
        'customers': (orders * 0.7).toInt(),
      };
    }

    if (selectedPeriod == 'Weekly') {
      final revenue = 200000;
      final orders = revenue ~/ 100;

      return {
        'revenue': revenue,
        'orders': orders,
        'customers': (orders * 0.75).toInt(),
      };
    }

    // Monthly
    final revenue = 900000 + _rand.nextInt(100000); // 900k–1M
    final orders = revenue ~/ 100;

    return {
      'revenue': revenue,
      'orders': orders,
      'customers': (orders * 0.8).toInt(),
    };
  }

  /// ================= CHART DATA =================
  List<double> getChartData() {
    if (selectedPeriod == 'Daily') {
      return [32000, 35000, 33000, 38000, 36000, 39000, 37000];
    } else if (selectedPeriod == 'Weekly') {
      return [180000, 195000, 188000, 205000, 198000, 210000, 200000];
    } else {
      return [850000, 920000, 880000, 950000, 910000, 980000, 920000];
    }
  }

  List<String> getChartLabels() {
    if (selectedPeriod == 'Daily') {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (selectedPeriod == 'Weekly') {
      return ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7'];
    } else {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: selectedPeriod,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
              items: const ['Daily', 'Weekly', 'Monthly']
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
        '₱100',
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
                'Revenue Analytics - $selectedPeriod',
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
                      '₱${(chartData[index] / 1000).toInt()}k',
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
              _summaryItem('Peak', '₱${(maxValue / 1000).toInt()}k', Icons.arrow_upward, Colors.green),
              _summaryItem('Average', '₱${(chartData.reduce((a, b) => a + b) / chartData.length / 1000).toInt()}k', Icons.equalizer, Colors.blue),
              _summaryItem('Low', '₱${(chartData.reduce((a, b) => a < b ? a : b) / 1000).toInt()}k', Icons.arrow_downward, Colors.orange),
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
            'Your ${selectedPeriod.toLowerCase()} performance shows strong growth with a ${(selectedPeriod == 'Daily' ? '12.5%' : selectedPeriod == 'Weekly' ? '15.2%' : '18.7%')} increase in revenue.',
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
