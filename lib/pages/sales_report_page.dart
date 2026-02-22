import 'dart:math';
import 'package:flutter/material.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  String selectedPeriod = 'Daily';
  final Random _rand = Random(10);

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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final data = getSalesSummary();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 24),
              _summaryCards(isDesktop, data),
              const SizedBox(height: 24),
              _detailsCard(data),
            ],
          ),
        ),
      ),
    );
  }

  /// ================= HEADER =================
  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Sales Report',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        DropdownButton<String>(
          value: selectedPeriod,
          items: const ['Daily', 'Weekly', 'Monthly']
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => selectedPeriod = v);
            }
          },
        ),
      ],
    );
  }

  /// ================= SUMMARY =================
  Widget _summaryCards(bool isDesktop, Map<String, int> data) {
    final cards = [
      _summaryCard(
        'Total Revenue',
        '₱${data['revenue']}',
        Icons.attach_money,
        Colors.green,
      ),
      _summaryCard(
        'Total Orders',
        '${data['orders']}',
        Icons.shopping_cart,
        Colors.blue,
      ),
      _summaryCard(
        'Avg Order',
        '₱100',
        Icons.receipt_long,
        Colors.orange,
      ),
      _summaryCard(
        'Customers',
        '${data['customers']}',
        Icons.people,
        Colors.purple,
      ),
    ];

    return isDesktop
        ? Row(children: cards.map((c) => Expanded(child: c)).toList())
        : Column(children: cards);
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ])
        ],
      ),
    );
  }

  /// ================= DETAILS =================
  Widget _detailsCard(Map<String, int> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedPeriod Summary',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _detailRow('Estimated Revenue', '₱${data['revenue']}'),
          _detailRow('Estimated Orders', '${data['orders']}'),
          _detailRow('Estimated Customers', '${data['customers']}'),
          _detailRow('Average Order Value', '₱100'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}