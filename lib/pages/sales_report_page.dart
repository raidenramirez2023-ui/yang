import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:csv/csv.dart' as csv_pkg;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:async';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage>
    with TickerProviderStateMixin {
  String selectedPeriod = 'Monthly';
  String selectedYear = '2026';
  final _supabase = Supabase.instance.client;
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _cardAnimationController;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All Status';
  String _transactionPeriod = 'All Time';
  late Stream<List<Map<String, dynamic>>> _ordersStreamVar;
  late Stream<List<Map<String, dynamic>>> _inventoryStreamVar;
  Timer? _refreshTimer;

  Stream<List<Map<String, dynamic>>> _ordersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> _inventoryStream() {
    return _supabase
        .from('inventory')
        .stream(primaryKey: ['id']);
  }

  Map<String, dynamic> _processMetrics(List<Map<String, dynamic>> allOrders) {
    final now = DateTime.now();
    final filteredOrders = allOrders.where((order) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) return false;
      
      // Filter by selected year first (except for yearly view)
      if (selectedPeriod != 'Annually' && date.year.toString() != selectedYear) {
        return false;
      }
      
      // Apply period-specific filtering
      switch (selectedPeriod) {
        case 'Daily':
          // Today's hourly data (real-time) - business hours 10:00 AM to 8:00 PM only
          final orderHour = date.hour;
          return date.year == now.year && 
              date.month == now.month && 
              date.day == now.day &&
              orderHour >= 10 && orderHour < 20; // Only 10:00 AM to 8:00 PM
        case 'Weekly':
          // Last 7 days of selected year
          final dailyDiff = now.difference(date).inDays;
          return dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == selectedYear;
        case 'Monthly':
          // All months of selected year
          return date.year.toString() == selectedYear;
        case 'Annually':
          // All years from 2016 to current year
          return date.year >= 2016 && date.year <= now.year;
        default:
          return false;
      }
    }).toList();
    
    if (filteredOrders.isEmpty) {
      return {'revenue': 0.0, 'orders': 0, 'customers': 0, 'avgOrder': 0.0};
    }

    double totalRevenue = 0;
    Set<String> uniqueCustomers = {};

    for (var order in filteredOrders) {
      totalRevenue += (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      uniqueCustomers.add(order['customer_name'] ?? 'Guest');
    }

    return {
      'revenue': totalRevenue,
      'orders': filteredOrders.length,
      'customers': uniqueCustomers.length,
      'avgOrder': totalRevenue / filteredOrders.length,
    };
  }

  List<double> _processChartData(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    Map<int, double> periodData = {};
    
    for (var order in orders) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) continue;
      
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      
      // Apply period-specific filtering
      switch (selectedPeriod) {
        case 'Daily':
          // Today's hourly data (real-time) - business hours 10:00 AM to 8:00 PM only
          final orderHour = date.hour;
          if (date.year == now.year && 
              date.month == now.month && 
              date.day == now.day &&
              orderHour >= 10 && orderHour < 20) { // Only 10:00 AM to 8:00 PM
            final key = orderHour - 10; // 0 = 10:00, 1 = 11:00, ..., 10 = 20:00
            periodData[key] = (periodData[key] ?? 0) + amount;
          }
          break;
        case 'Weekly':
          // Last 7 days - group by day of week (Monday=0, Tuesday=1, etc.)
          final dailyDiff = now.difference(date).inDays;
          if (dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == selectedYear) {
            final key = date.weekday - 1; // 0 = Monday, 6 = Sunday
            periodData[key] = (periodData[key] ?? 0) + amount;
          }
          break;
        case 'Monthly':
          // All months of selected year
          if (date.year.toString() == selectedYear) {
            final key = date.month - 1; // 0 = Jan, 11 = Dec
            periodData[key] = (periodData[key] ?? 0) + amount;
          }
          break;
        case 'Annually':
          // Years 2016 to current year
          if (date.year >= 2016 && date.year <= now.year) {
            final key = date.year - 2016; // 0 = 2016, 10 = 2026
            periodData[key] = (periodData[key] ?? 0) + amount;
          }
          break;
      }
    }
    
    // Convert to list based on selected period
    if (selectedPeriod == 'Daily') {
      return List.generate(11, (i) => periodData[i] ?? 0.0); // 11 business hours: 10:00-20:00
    } else if (selectedPeriod == 'Weekly') {
      return List.generate(7, (i) => periodData[i] ?? 0.0);
    } else if (selectedPeriod == 'Monthly') {
      return List.generate(12, (i) => periodData[i] ?? 0.0);
    } else {
      // For yearly, generate from 2016 to current year
      final currentYear = now.year;
      final yearRange = currentYear - 2016 + 1;
      return List.generate(yearRange, (i) => periodData[i] ?? 0.0);
    }
  }

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
    
    _ordersStreamVar = _ordersStream();
    _inventoryStreamVar = _inventoryStream();
    
    // Start automatic refresh timer for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to show new orders immediately
      }
    });
    
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _searchController.dispose();
    _refreshTimer?.cancel(); // Cancel the refresh timer
    super.dispose();
  }

  Future<void> _exportToCSV(List<Map<String, dynamic>> transactions, String fileName, {Map<String, dynamic>? metrics}) async {
    if (transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export')),
        );
      }
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  SizedBox(height: 16),
                  Text('Preparing CSV...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Fetch all items for these orders
      final orderIds = transactions.map((t) => t['db_id']).toList();
      final itemsResponse = await _supabase
          .from('order_items')
          .select('order_id, item_name, quantity')
          .inFilter('order_id', orderIds);

      final List<Map<String, dynamic>> allItems = List<Map<String, dynamic>>.from(itemsResponse);
      
      // Group items by order id
      Map<String, String> itemsMap = {};
      for (var item in allItems) {
        final orderId = item['order_id'].toString();
        final itemStr = '${item['item_name']} x${item['quantity']}';
        if (itemsMap.containsKey(orderId)) {
          itemsMap[orderId] = '${itemsMap[orderId]}, $itemStr';
        } else {
          itemsMap[orderId] = itemStr;
        }
      }

      // Remove loading indicator
      if (mounted) Navigator.pop(context);

      // Prepare CSV data
      List<List<dynamic>> rows = [];

      if (metrics != null) {
        rows.add(['SALES REPORT SUMMARY (${selectedPeriod.toUpperCase()} - $selectedYear)']);
        rows.add(['Total Revenue', _currencyFormat.format(metrics['revenue']).replaceAll('₱', 'PHP ')]);
        rows.add(['Total Orders', metrics['orders']]);
        rows.add(['Average Order', _currencyFormat.format(metrics['avgOrder']).replaceAll('₱', 'PHP ')]);
        rows.add(['Active Customers', metrics['customers']]);
        rows.add(['Low Stock Items', metrics['lowStock']]);
        rows.add([]); // Empty spacer row
        rows.add(['RECENT TRANSACTIONS']);
      }

      // Headers
      rows.add(['ID', 'Customer', 'Items', 'Date', 'Amount', 'Status']);

      for (var t in transactions) {
        rows.add([
          t['id'],
          t['customer'],
          itemsMap[t['db_id']] ?? 'No items',
          t['date'],
          t['amount'].toString().replaceAll('₱', '').replaceAll(',', ''),
          t['status'],
        ]);
      }
      String csvData = csv_pkg.CsvCodec().encode(rows);
      final Uint8List bytes = utf8.encode(csvData);

      // Save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sales Report',
        fileName: '$fileName.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile != null) { 
        if (!kIsWeb) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File saved successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Safe check to pop dialog if it's still showing
        if (Navigator.canPop(context)) Navigator.pop(context);
        
        debugPrint('Export failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }


  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}m';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(0)}k';
    } else {
      return '₱${amount.toStringAsFixed(0)}';
    }
  }

  List<String> getChartLabels() {
    if (selectedPeriod == 'Daily') {
      // Business hours only: 10:00 AM to 8:00 PM (10:00 to 20:00)
      return ['10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'];
    } else if (selectedPeriod == 'Weekly') {
      return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    } else if (selectedPeriod == 'Monthly') {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    } else {
      // Annual - 2016 to current year (2026)
      return ['2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _ordersStreamVar,
          builder: (context, orderSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _inventoryStreamVar,
              builder: (context, invSnapshot) {

                final allOrders = orderSnapshot.data ?? [];
                final allInventory = invSnapshot.data ?? [];
                
                final metrics = _processMetrics(allOrders);
                final chartValues = _processChartData(allOrders);
                
                final now = DateTime.now();
                final isBusinessHours = now.hour >= 10 && now.hour < 20; // 10:00 AM to 8:00 PM
                
                final lowStockCount = allInventory.where((item) {
                  final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                  // For Daily view, only count low stock if currently within business hours
                  if (selectedPeriod == 'Daily' && !isBusinessHours) {
                    return false; // Don't count low stock outside business hours for Daily view
                  }
                  return qty < 10;
                }).length;

                metrics['lowStock'] = lowStockCount;

                // Process all orders for the table (filtered by transaction period)
                final tableTransactions = allOrders.where((o) {
                  final date = DateTime.tryParse(o['created_at'] ?? '');
                  if (date == null) return false;
                  
                  final now = DateTime.now();
                  
                  if (_transactionPeriod == 'Daily') {
                    if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
                  } else if (_transactionPeriod == 'Weekly') {
                    // last 7 days
                    if (now.difference(date).inDays > 7) return false;
                  } else if (_transactionPeriod == 'Monthly') {
                    if (date.year != now.year || date.month != now.month) return false;
                  } else if (_transactionPeriod == 'Yearly') {
                    if (date.year != now.year) return false;
                  }
                  
                  return true;
                }).map((o) {
                  final name = o['customer_name'] ?? 'Guest';
                  final dbStatus = o['kitchen_status']?.toString() ?? 'Pending';
                  
                  // Map DB status to UI status
                  String uiStatus = dbStatus;
                  if (dbStatus == 'Done' || dbStatus == 'Ready') uiStatus = 'Ready';
                  
                  return {
                    'db_id': o['id'].toString(),
                    'id': '#${o['transaction_id'] ?? o['id']}',
                    'customer': name,
                    'date': DateFormat('MMM d, yyyy').format(DateTime.parse(o['created_at'])),
                    'amount': _currencyFormat.format(o['total_amount']),
                    'status': uiStatus,
                    'internal_status': dbStatus,
                    'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                    'color': Colors.blue,
                  };
                }).toList();

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(tableTransactions, metrics),
                        const SizedBox(height: 32),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryCards(isDesktop, metrics),
                                const SizedBox(height: 32),
                                _chartCard(chartValues),
                                const SizedBox(height: 32),
                                _transactionsSection(tableTransactions),
                                const SizedBox(height: 32),
                                _insightsCard(metrics),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            );
          }
        ),
      ),
    );
  }

  /// ================= HEADER =================
  Widget _header(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Report',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Track your business performance and metrics',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _periodSelector()),
              const SizedBox(width: 12),
              Expanded(child: _yearSelector()),
            ],
          ),
          const SizedBox(height: 12),
          _exportButton(transactions, metrics),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Report',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your business performance and metrics',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        _periodSelector(),
        const SizedBox(width: 12),
        _yearSelector(),
        const SizedBox(width: 12),
        _exportButton(transactions, metrics),
      ],
    );
  }

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<String>(
        value: selectedPeriod,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: ['Daily', 'Weekly', 'Monthly', 'Annually']
            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) => setState(() => selectedPeriod = v!),
      ),
    );
  }


  Widget _yearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: selectedYear,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            items: ['2023', '2024', '2025', '2026']
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => selectedYear = v!),
          ),
        ],
      ),
    );
  }

  Widget _exportButton(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    return ElevatedButton.icon(
      onPressed: () => _exportToCSV(
        transactions, 
        'Sales_Report_${selectedYear}_$selectedPeriod',
        metrics: metrics,
      ),
      icon: const Icon(Icons.file_download_outlined, size: 18),
      label: const Text('Export'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  /// ================= SUMMARY =================
  Widget _summaryCards(bool isDesktop, Map<String, dynamic> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _summaryCard(
            'Total Revenue',
            _currencyFormat.format(data['revenue']),
            Icons.payments_rounded,
            const Color(0xFF4F46E5),
            '+12.5%',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Total Orders',
            data['orders'].toString(),
            Icons.shopping_bag_rounded,
            const Color(0xFF10B981),
            '+8.2%',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Avg. Order',
            _currencyFormat.format(data['avgOrder']),
            Icons.analytics_rounded,
            const Color(0xFFF59E0B),
            '+3.1%',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Active Customers',
            data['customers'].toString(),
            Icons.people_alt_rounded,
            const Color(0xFFEC4899),
            '+5.4%',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Low Stock Items',
            data['lowStock'].toString(),
            Icons.warning_amber_rounded,
            data['lowStock'] > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            'Alert',
            200,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color,
      String growth, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  growth,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  /// ================= CHART CARD =================
  Widget _chartCard(List<double> chartValues) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: const Text(
                            'Actual Revenue',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 350,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: (chartValues.isEmpty ? 1000.0 : chartValues.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, 10000000.0).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _currencyFormat.format(rod.toY),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = getChartLabels();
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _formatCurrency(value),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                        );
                      },
                      reservedSize: 45,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: chartValues.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: const Color(0xFF4F46E5),
                        width: 20,
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

  Widget _transactionsSection(List<Map<String, dynamic>> transactions) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _transactionFilters(transactions, isVertical: true),
              ],
            )
          else
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _transactionFilters(transactions),
              ],
            ),
          const SizedBox(height: 32),
          _transactionsTable(transactions),
        ],
      ),
    );
  }

  Widget _transactionFilters(List<Map<String, dynamic>> transactions, {bool isVertical = false}) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (isVertical || isMobile) {
      return SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            final filteredTransactions = transactions.where((t) {
              if (_statusFilter == 'All Status') return true;
              return t['status'] == _statusFilter;
            }).toList();
            _exportToCSV(filteredTransactions, 'Transactions_${_statusFilter.replaceAll(' ', '_')}');
          },
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Download CSV'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
        ),
      );
    }
    
    return TextButton.icon(
      onPressed: () {
        final filteredTransactions = transactions.where((t) {
          if (_statusFilter == 'All Status') return true;
          return t['status'] == _statusFilter;
        }).toList();
        _exportToCSV(filteredTransactions, 'Transactions_${_statusFilter.replaceAll(' ', '_')}');
      },
      icon: const Icon(Icons.file_download_outlined, size: 18),
      label: const Text('Download CSV'),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
    );
  }

  Widget _transactionsTable(List<Map<String, dynamic>> transactions) {
    // Apply UI Level Filtering
    final filteredTransactions = transactions.where((t) {
      // Status Filter
      bool matchesStatus = _statusFilter == 'All Status' || t['status'] == _statusFilter;
      
      // Search Filter
      String query = _searchController.text.toLowerCase().trim();
      if (query.isEmpty) return matchesStatus;

      // Extract raw data for searching (remove # and ₱ etc)
      String id = t['id'].toString().toLowerCase().replaceAll('#', '');
      String customer = t['customer'].toString().toLowerCase();
      
      bool matchesSearch = id.contains(query) || customer.contains(query);
          
      return matchesStatus && matchesSearch;
    }).toList();

    return Column(
      children: [
        if (ResponsiveUtils.isMobile(context))
          Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Filter by:', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        underline: const SizedBox(),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        items: ['All Status', 'Ready', 'Pending', 'Cancelled']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _statusFilter = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String>(
                        value: _transactionPeriod,
                        underline: const SizedBox(),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        items: ['All Time', 'Daily', 'Weekly', 'Monthly', 'Yearly']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _transactionPeriod = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Filter by:', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: ['All Status', 'Ready', 'Pending', 'Cancelled']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String>(
                  value: _transactionPeriod,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: ['All Time', 'Daily', 'Weekly', 'Monthly', 'Yearly']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _transactionPeriod = v!),
                ),
              ),
            ],
          ),
        const SizedBox(height: 32),
        if (filteredTransactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              _statusFilter == 'All Status' 
                ? 'No transactions found' 
                : 'No ${_statusFilter.toLowerCase()} transactions found', 
              style: const TextStyle(color: Color(0xFF64748B))
            ),
          )
        else if (ResponsiveUtils.isMobile(context))
          ...filteredTransactions.map((t) => _transactionCard(t))
        else
          Column(
            children: [
              _transactionTableHeader(),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),
              ...filteredTransactions.map((t) => _transactionRow(t)),
            ],
          ),
      ],
    );
  }

  Widget _transactionTableHeader() {
    const style = TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12);
    return const Row(
      children: [
        Expanded(flex: 1, child: Text('ID', style: style)),
        Expanded(flex: 2, child: Text('CUSTOMER', style: style)),
        Expanded(flex: 3, child: Text('ITEMS', style: style)),
        Expanded(flex: 2, child: Text('DATE', style: style)),
        Expanded(flex: 1, child: Text('AMOUNT', style: style)),
        Expanded(flex: 1, child: Text('STATUS', style: style)),
      ],
    );
  }

  Widget _transactionRow(Map<String, dynamic> t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(t['id'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: (t['color'] as Color).withValues(alpha: 0.1),
                  child: Text(t['initials'], style: TextStyle(color: t['color'], fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(t['customer'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 12), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('order_items')
                  .select('item_name, quantity')
                  .eq('order_id', t['db_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('');
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No items', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11));
                }
                
                final items = snapshot.data!;
                final itemsStr = items.map((i) => '${i['item_name']} x${i['quantity']}').join(', ');
                
                return Text(
                  itemsStr,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          Expanded(flex: 2, child: Text(t['date'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
          Expanded(
            flex: 1,
            child: Text(t['amount'], style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: _statusBadge(t['status']),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: (t['color'] as Color).withValues(alpha: 0.1),
                    child: Text(t['initials'], style: TextStyle(color: t['color'], fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['customer'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14)),
                      Text(t['id'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ],
              ),
              _statusBadge(t['status']),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('order_items')
                .select('item_name, quantity')
                .eq('order_id', t['db_id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Loading items...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No items', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12));
              }
              
              final items = snapshot.data!;
              final itemsStr = items.map((i) => '${i['item_name']} x${i['quantity']}').join(', ');
              
              return Text(
                itemsStr,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['date'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              Text(t['amount'], style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    switch (status) {
      case 'Ready':
      case 'Done':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        status = 'Ready';
        break;
      case 'Preparing':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF2563EB);
        break;
      case 'Pending':
        bg = const Color(0xFFFEF9C3);
        text = const Color(0xFFCA8A04);
        break;
      case 'Cancelled':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }


  /// ================= INSIGHTS CARD =================
  Widget _insightsCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Insights',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your revenue has grown by 12.5% compared to the previous period. The increase is primarily driven by a surge in "Total Customers" which grew by 15.7%. Consider focusing on customer retention strategies to maintain this upward momentum throughout the quarter.',
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('View Detailed Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}