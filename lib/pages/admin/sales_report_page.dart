import 'dart:math';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:csv/csv.dart' as csv_pkg;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:yang_chow/services/location_analytics_service.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage>
    with TickerProviderStateMixin {
  String selectedPeriod = 'Monthly';
  String selectedYear = '2026';
  String selectedChartType = 'Line';
  Set<String> activeStreams = {'Regular'};
  bool _showEventReservationPerformance = false;
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
  late Stream<List<Map<String, dynamic>>> _advanceOrdersStreamVar;
  late Stream<List<Map<String, dynamic>>> _reservationsStreamVar;
  Timer? _refreshTimer;
  
  // Location analytics
  final LocationAnalyticsService _locationAnalyticsService = LocationAnalyticsService();
  List<Map<String, dynamic>> _locationData = [];
  bool _isLoadingLocationData = false;
  String _locationPeriod = 'All Time';

  // Hide-on-scroll header
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollOffset = 0;

  // Pagination state
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  Stream<List<Map<String, dynamic>>> _ordersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> _advanceOrdersStream() {
    return _supabase
        .from('advance_orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> _reservationsStream() {
    return _supabase
        .from('reservations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> _inventoryStream() {
    return _supabase
        .from('inventory')
        .stream(primaryKey: ['id']);
  }

  Map<String, dynamic> _processMetrics(
      List<Map<String, dynamic>> allOrders,
      List<Map<String, dynamic>> allAdvanceOrders,
      List<Map<String, dynamic>> allReservations) {
    final now = DateTime.now();
    // Combine regular orders
    List<Map<String, dynamic>> combinedOrders = [];
    
    // Add regular orders
    combinedOrders.addAll(allOrders.where((order) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) return false;
      
      // Filter by selected year first (except for yearly view)
      if (selectedPeriod != 'Annually' && date.year.toString() != selectedYear) {
        return false;
      }
      
      // Apply period-specific filtering
      switch (selectedPeriod) {
        case 'Daily':
          return date.year == now.year && 
              date.month == now.month && 
              date.day == now.day;
        case 'Weekly':
          final dailyDiff = now.difference(date).inDays;
          return dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == selectedYear;
        case 'Monthly':
          return date.year.toString() == selectedYear;
        case 'Annually':
          return date.year >= 2016 && date.year <= now.year;
        default:
          return false;
      }
    }).toList());
    
    double totalRevenue = 0;
    Set<String> uniqueCustomers = {};

    for (var order in combinedOrders) {
      double amount = 0.0;
      if (order['is_reservation'] == true) {
        final paymentStatus = order['payment_status']?.toString() ?? '';
        if (paymentStatus == 'deposit_paid') {
          amount = (order['deposit_amount'] as num?)?.toDouble() ?? 
                   ((order['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
        } else if (paymentStatus == 'fully_paid' || paymentStatus == 'paid') {
          final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;
          final depositAmount = (order['deposit_amount'] as num?)?.toDouble() ?? 0.0;
          amount = totalPrice - depositAmount;
        } else {
          amount = (order['total_price'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        amount = order.containsKey('total_amount') 
            ? (order['total_amount'] as num?)?.toDouble() ?? 0.0
            : (order['total_price'] as num?)?.toDouble() ?? 0.0;
      }
      totalRevenue += amount;
      final name = order['customer_name']?.toString() ?? 'Guest';
      if (name.isNotEmpty) {
        uniqueCustomers.add(name);
      }
    }

    // Helper to check if a date is within the selected period
    bool isDateInPeriod(DateTime date) {
      if (selectedPeriod != 'Annually' && date.year.toString() != selectedYear) {
        return false;
      }
      switch (selectedPeriod) {
        case 'Daily':
          return date.year == now.year && 
              date.month == now.month && 
              date.day == now.day;
        case 'Weekly':
          final dailyDiff = now.difference(date).inDays;
          return dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == selectedYear;
        case 'Monthly':
          return date.year.toString() == selectedYear;
        case 'Annually':
          return date.year >= 2016 && date.year <= now.year;
        default:
          return false;
      }
    }

    // Also count unique customers from paid advance orders within the selected period
    for (var advOrder in allAdvanceOrders) {
      final paymentStatus = advOrder['payment_status']?.toString() ?? '';
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
      if (!isPaid) continue;

      final date = DateTime.tryParse(advOrder['order_date'] ?? '');
      if (date == null) continue;

      if (isDateInPeriod(date)) {
        final name = advOrder['customer_name']?.toString() ?? 'Guest';
        if (name.isNotEmpty) {
          uniqueCustomers.add(name);
        }
      }
    }

    // Also count unique customers from confirmed/completed event reservations within the selected period
    for (var res in allReservations) {
      final status = (res['status']?.toString() ?? '').toLowerCase();
      if (status != 'confirmed' && status != 'completed') continue;

      final date = DateTime.tryParse(res['event_date'] ?? '');
      if (date == null) continue;

      if (isDateInPeriod(date)) {
        final name = res['customer_name']?.toString() ?? 'Guest';
        if (name.isNotEmpty) {
          uniqueCustomers.add(name);
        }
      }
    }

    return {
      'revenue': totalRevenue,
      'orders': combinedOrders.length,
      'customers': uniqueCustomers.length,
      'avgOrder': combinedOrders.isEmpty ? 0.0 : totalRevenue / combinedOrders.length,
    };
  }

  Map<String, List<double>> _processChartData(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> advanceOrders,
      List<Map<String, dynamic>> reservations) {
    final now = DateTime.now();
    Map<int, double> regularData = {};
    Map<int, double> advanceData = {};
    Map<int, double> reservationData = {};

    // Helper to process regular orders only
    // Sales Report now only includes regular orders (walk-in orders)
    // Advance orders and event reservations are excluded from this report
    for (var order in orders) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) continue;

      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      _addToPeriodData(date, amount, regularData, now);
    }

    int length = 0;
    if (selectedPeriod == 'Daily') {
      length = 11; // Business hours only: 10am to 8pm (10:00 to 20:00)
    } else if (selectedPeriod == 'Weekly') {
      length = 7;
    } else if (selectedPeriod == 'Monthly') {
      length = 12;
    } else {
      length = now.year - 2016 + 1;
    }

    return {
      'regular': List.generate(length, (i) => regularData[i] ?? 0.0),
      'advance': List.generate(length, (i) => 0.0),
      'reservation': List.generate(length, (i) => 0.0),
    };
  }

  void _addToPeriodData(
      DateTime date,
      double amount,
      Map<int, double> periodData,
      DateTime now, {
      bool isAdvance = false,
      Map<String, dynamic>? advanceOrder,
      bool isReservation = false,
      Map<String, dynamic>? reservation,
  }) {
    switch (selectedPeriod) {
      case 'Daily':
        if (date.year == now.year && 
            date.month == now.month && 
            date.day == now.day &&
            date.hour >= 10 &&
            date.hour <= 20) {
           // Map hour to 0-based index within business hours (10:00–20:00)
           final key = date.hour - 10;
           periodData[key] = (periodData[key] ?? 0) + amount;
        }
        break;
      case 'Weekly':
        final dailyDiff = now.difference(date).inDays;
        if (dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == selectedYear) {
          final key = date.weekday - 1;
          periodData[key] = (periodData[key] ?? 0) + amount;
        }
        break;
      case 'Monthly':
        if (date.year.toString() == selectedYear) {
          final key = date.month - 1;
          periodData[key] = (periodData[key] ?? 0) + amount;
        }
        break;
      case 'Annually':
        if (date.year >= 2016 && date.year <= now.year) {
          final key = date.year - 2016;
          periodData[key] = (periodData[key] ?? 0) + amount;
        }
        break;
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
    _advanceOrdersStreamVar = _advanceOrdersStream();
    _reservationsStreamVar = _reservationsStream();
    
    // Fetch location analytics data
    _fetchLocationData();
    
    // Start automatic refresh timer for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchLocationData(); // Refresh location data
        setState(() {}); // Trigger rebuild to show new orders immediately
      }
    });
    
    _searchController.addListener(() {
      setState(() {});
    });

    // Hide header on scroll down, show on scroll up
    _scrollController.addListener(() {
      final currentOffset = _scrollController.offset;
      final diff = currentOffset - _lastScrollOffset;
      if (diff > 8 && _isHeaderVisible) {
        setState(() => _isHeaderVisible = false);
      } else if (diff < -8 && !_isHeaderVisible) {
        setState(() => _isHeaderVisible = true);
      }
      _lastScrollOffset = currentOffset;
    });
  }

  Future<void> _fetchLocationData() async {
    setState(() {
      _isLoadingLocationData = true;
    });

    try {
      DateTime? startDate;
      DateTime? endDate;
      final now = DateTime.now();

      switch (_locationPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case 'All Time':
        default:
          startDate = null;
          endDate = null;
          break;
      }

      final data = await _locationAnalyticsService.getLocationAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      if (mounted) {
        setState(() {
          _locationData = data;
          _isLoadingLocationData = false;
        });
      }
    } catch (e) {
      print('Error fetching location data: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocationData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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

      // Fetch all items for regular orders
      final orderIds = transactions
          .where((t) => t['type'] == 'Regular')
          .map((t) => t['db_id'])
          .toList();

      Map<String, String> itemsMap = {};
      if (orderIds.isNotEmpty) {
        final itemsResponse = await _supabase
            .from('order_items')
            .select('order_id, item_name, quantity')
            .inFilter('order_id', orderIds);

        final List<Map<String, dynamic>> allItems =
            List<Map<String, dynamic>>.from(itemsResponse);

        // Group items by order id
        for (var item in allItems) {
          final orderId = item['order_id'].toString();
          final itemStr = '${item['item_name']} x${item['quantity']}';
          if (itemsMap.containsKey(orderId)) {
            itemsMap[orderId] = '${itemsMap[orderId]}, $itemStr';
          } else {
            itemsMap[orderId] = itemStr;
          }
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
        rows.add(['Unique Customers', metrics['customers']]);
        rows.add(['Low Stock Items', metrics['lowStock']]);
        
        // Add Advance Order Performance Summary
        if (metrics.containsKey('advanceOrderRevenue')) {
          rows.add([]);
          rows.add(['ADVANCE ORDER PERFORMANCE (HISTORICAL)']);
          rows.add(['Total AO Revenue', _currencyFormat.format(metrics['advanceOrderRevenue']).replaceAll('₱', 'PHP ')]);
          rows.add(['AO Completed', metrics['advanceOrderCompleted']]);
          rows.add(['Cancellation Rate', '${(metrics['advanceOrderCancellationRate'] as double).toStringAsFixed(1)}%']);
          
          if (metrics['popularAdvanceItems'] != null) {
            final Map<String, int> popItems = Map<String, int>.from(metrics['popularAdvanceItems']);
            if (popItems.isNotEmpty) {
              rows.add(['Popular Advance Order Items', 'Orders Count']);
              final sortedItems = popItems.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              for (var entry in sortedItems) {
                rows.add([entry.key, entry.value]);
              }
            }
          }
        }
        
        // Add Event Reservation Performance Summary
        if (metrics.containsKey('eventReservationRevenue')) {
          rows.add([]);
          rows.add(['EVENT RESERVATION PERFORMANCE (HISTORICAL)']);
          rows.add(['Total Event Revenue', _currencyFormat.format(metrics['eventReservationRevenue']).replaceAll('₱', 'PHP ')]);
          rows.add(['Events Completed', metrics['eventReservationCompleted']]);
          rows.add(['Cancellation Rate', '${(metrics['eventReservationCancellationRate'] as double).toStringAsFixed(1)}%']);
          
          if (metrics['popularEventTypes'] != null) {
            final Map<String, int> popEvents = Map<String, int>.from(metrics['popularEventTypes']);
            if (popEvents.isNotEmpty) {
              rows.add(['Popular Event Types', 'Completed Count']);
              final sortedEvents = popEvents.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              for (var entry in sortedEvents) {
                rows.add([entry.key, entry.value]);
              }
            }
          }
        }
        
        // Add Location Analytics Summary
        if (_locationData.isNotEmpty) {
          rows.add([]);
          rows.add(['LOCATION ANALYTICS ($_locationPeriod)']);
          rows.add(['City/Municipality', 'Order Count']);
          final sortedLocations = _locationData.toList()..sort((a, b) => (b['order_count'] as int).compareTo(a['order_count'] as int));
          for (var location in sortedLocations) {
            rows.add([location['location']?.toString() ?? 'Unknown', location['order_count']?.toString() ?? '0']);
          }
        }

        rows.add([]); // Empty spacer row
        rows.add(['RECENT TRANSACTIONS']);
      }

      // Headers
      rows.add(['ID', 'Customer', 'Items', 'Date', 'Amount', 'Status']);

      for (var t in transactions) {
        String itemsStr = 'No items';
        if ((t['type'] == 'Advance' || t['type'] == 'Reservation') && t['selected_menu_items'] != null) {
          final Map<String, dynamic> items = Map<String, dynamic>.from(t['selected_menu_items']);
          itemsStr = items.entries.map((e) => '${e.key} x${e.value}').join(', ');
        } else {
          itemsStr = itemsMap[t['db_id']] ?? 'No items';
        }

        rows.add([
          t['id'],
          t['customer'],
          itemsStr,
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
              stream: _advanceOrdersStreamVar,
              builder: (context, advanceOrderSnapshot) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _reservationsStreamVar,
                  builder: (context, reservationsSnapshot) {
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _inventoryStreamVar,
                      builder: (context, invSnapshot) {

                        final allOrders = orderSnapshot.data ?? [];
                        final allAdvanceOrders = advanceOrderSnapshot.data ?? [];
                        final allReservations = reservationsSnapshot.data ?? [];
                        final allInventory = invSnapshot.data ?? [];
                        
                        final metrics = _processMetrics(allOrders, allAdvanceOrders, allReservations);
                        final chartValues = _processChartData(allOrders, allAdvanceOrders, allReservations);
                        
                        final now = DateTime.now();
                        final isBusinessHours = now.hour >= 10 && now.hour <= 20; // 10:00 AM to 8:00 PM
                        
                        final lowStockCount = allInventory.where((item) {
                          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                          // For Daily view, only count low stock if currently within business hours
                          if (selectedPeriod == 'Daily' && !isBusinessHours) {
                            return false; // Don't count low stock outside business hours for Daily view
                          }
                          return qty < 10;
                        }).length;

                        metrics['lowStock'] = lowStockCount;

                        // Combine regular orders, paid advance orders, and paid reservations for the table
                        List<Map<String, dynamic>> combinedTransactions = [];
                        
                        // Add regular orders
                        combinedTransactions.addAll(allOrders.where((o) {
                          final date = DateTime.tryParse(o['created_at'] ?? '');
                          if (date == null) return false;
                          
                          if (_transactionPeriod == 'Daily') {
                            if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
                          } else if (_transactionPeriod == 'Weekly') {
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
                            'type': 'Regular',
                          };
                        }).toList());
                        
                        // Add paid advance orders
                        combinedTransactions.addAll(allAdvanceOrders.where((o) {
                          final date = DateTime.tryParse(o['order_date'] ?? '');
                          if (date == null) return false;
                          
                          // Include all advance orders (remove payment status filter to show all)
                          // Only filter by date period
                          
                          if (_transactionPeriod == 'Daily') {
                            if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
                          } else if (_transactionPeriod == 'Weekly') {
                            if (now.difference(date).inDays > 7) return false;
                          } else if (_transactionPeriod == 'Monthly') {
                            if (date.year != now.year || date.month != now.month) return false;
                          } else if (_transactionPeriod == 'Yearly') {
                            if (date.year != now.year) return false;
                          }
                          
                          return true;
                        }).map((o) {
                          final name = o['customer_name'] ?? 'Guest';
                          final status = o['status']?.toString().toLowerCase() ?? 'pending';
                          
                          return {
                            'db_id': o['id'].toString(),
                            'id': '#AO-${o['id']}',
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(DateTime.parse(o['order_date'] ?? '')),
                            'amount': _currencyFormat.format(o['total_price']),
                            'status': status[0].toUpperCase() + status.substring(1),
                            'internal_status': status,
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': Colors.green,
                            'type': 'Advance',
                            'selected_menu_items': o['selected_menu_items'],
                          };
                        }).toList());

                        // Add paid event reservations
                        combinedTransactions.addAll(allReservations.where((r) {
                          final date = DateTime.tryParse(r['event_date'] ?? '');
                          if (date == null) return false;

                          final paymentStatus = r['payment_status']?.toString() ?? '';
                          final isPaid = paymentStatus == 'paid' ||
                              paymentStatus == 'fully_paid' ||
                              paymentStatus == 'deposit_paid';
                          if (!isPaid) return false;

                          if (_transactionPeriod == 'Daily') {
                            if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
                          } else if (_transactionPeriod == 'Weekly') {
                            if (now.difference(date).inDays > 7) return false;
                          } else if (_transactionPeriod == 'Monthly') {
                            if (date.year != now.year || date.month != now.month) return false;
                          } else if (_transactionPeriod == 'Yearly') {
                            if (date.year != now.year) return false;
                          }

                          return true;
                        }).map((r) {
                          final name = r['customer_name'] ?? 'Guest';
                          final status = r['status']?.toString().toLowerCase() ?? 'pending';
                          final paymentStatus = r['payment_status']?.toString() ?? '';
                          
                          double amount = 0.0;
                          if (paymentStatus == 'deposit_paid') {
                            amount = (r['deposit_amount'] as num?)?.toDouble() ?? 
                                     ((r['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
                          } else {
                            amount = (r['total_price'] as num?)?.toDouble() ?? 0.0;
                          }

                          return {
                            'db_id': r['id'].toString(),
                            'id': '#RES-${r['id']}',
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(DateTime.parse(r['event_date'] ?? '')),
                            'amount': _currencyFormat.format(amount),
                            'status': status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Pending',
                            'internal_status': status,
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': Colors.purple,
                            'type': 'Reservation',
                            'selected_menu_items': r['selected_menu_items'],
                          };
                        }).toList());
                        
                        final tableTransactions = combinedTransactions;

                        // Calculate Advance Order Performance (Historical)
                        final double advanceOrderRevenueTotal = allAdvanceOrders
                            .where((o) =>
                                o['payment_status'] == 'paid' ||
                                o['payment_status'] == 'fully_paid')
                            .fold(0.0, (sum, o) => sum + ((o['total_price'] as num?)?.toDouble() ?? 0.0));

                        final int completedAdvanceOrdersCount = allAdvanceOrders
                            .where((o) =>
                                o['status'] == 'done' ||
                                o['status'] == 'completed' ||
                                o['status'] == 'ready')
                            .length;

                        final int cancelledAdvanceOrdersCount = allAdvanceOrders
                            .where((o) => o['status'] == 'cancelled')
                            .length;

                        final int totalAdvAttempts = allAdvanceOrders.length;
                        final double advanceCancellationRate = totalAdvAttempts > 0
                            ? (cancelledAdvanceOrdersCount / totalAdvAttempts) * 100
                            : 0.0;

                        final Map<String, int> popularAdvanceItems = {};
                        for (var o in allAdvanceOrders) {
                          if (o['status'] == 'done' ||
                              o['status'] == 'completed' ||
                              o['status'] == 'ready') {
                            final items = o['selected_menu_items'] as Map<String, dynamic>? ?? {};
                            items.forEach((name, qty) {
                              popularAdvanceItems[name] = (popularAdvanceItems[name] ?? 0) + (qty as num).toInt();
                            });
                          }
                        }

                        // Calculate Event Reservation Performance (Historical)
                        final paidEventReservations = allReservations.where((r) {
                          final paymentStatus = r['payment_status']?.toString() ?? '';
                          final status = r['status']?.toString() ?? '';
                          final isPaid = paymentStatus == 'paid' ||
                              paymentStatus == 'fully_paid' ||
                              paymentStatus == 'deposit_paid';
                          final isAdminApproved = status == 'confirmed';
                          return isPaid && isAdminApproved;
                        }).toList();

                        final double eventReservationRevenueTotal = paidEventReservations.fold(0.0, (sum, r) {
                          final paymentStatus = r['payment_status']?.toString() ?? '';
                          if (paymentStatus == 'deposit_paid') {
                            final amount = (r['deposit_amount'] as num?)?.toDouble() ??
                                ((r['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
                            return sum + amount;
                          } else {
                            final amount = (r['total_price'] as num?)?.toDouble() ?? 0.0;
                            return sum + amount;
                          }
                        });

                        final int completedEventReservationsCount = allReservations
                            .where((r) => r['status'] == 'completed')
                            .length;

                        final int cancelledEventReservationsCount = allReservations
                            .where((r) => r['status'] == 'cancelled')
                            .length;

                        final int totalEventAttempts = allReservations.length;
                        final double eventCancellationRate = totalEventAttempts > 0
                            ? (cancelledEventReservationsCount / totalEventAttempts) * 100
                            : 0.0;

                        final Map<String, int> popularEventTypes = {};
                        for (var r in allReservations) {
                          if (r['status'] == 'completed') {
                            final eventType = r['event_type']?.toString() ?? 'Unknown';
                            popularEventTypes[eventType] = (popularEventTypes[eventType] ?? 0) + 1;
                          }
                        }

                        metrics['advanceOrderRevenue'] = advanceOrderRevenueTotal;
                        metrics['advanceOrderCompleted'] = completedAdvanceOrdersCount;
                        metrics['advanceOrderCancellationRate'] = advanceCancellationRate;
                        metrics['popularAdvanceItems'] = popularAdvanceItems;

                        metrics['eventReservationRevenue'] = eventReservationRevenueTotal;
                        metrics['eventReservationCompleted'] = completedEventReservationsCount;
                        metrics['eventReservationCancellationRate'] = eventCancellationRate;
                        metrics['popularEventTypes'] = popularEventTypes;

                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: EdgeInsets.all(isDesktop ? 32 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hide-on-scroll header
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _isHeaderVisible ? 1.0 : 0.0,
                                    child: _isHeaderVisible
                                        ? Column(
                                            children: [
                                              _header(tableTransactions, metrics),
                                              const SizedBox(height: 32),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _summaryCards(isDesktop, metrics),
                                        const SizedBox(height: 32),
                                        _chartCard(chartValues),
                                        const SizedBox(height: 32),
                                        _buildClickableSectionTitle(
                                          context,
                                          'Advance Order Performance',
                                          () {
                                            setState(() {
                                              _showEventReservationPerformance =
                                                  !_showEventReservationPerformance;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: AppTheme.md),
                                        ResponsiveUtils.isMobile(context)
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildAdvanceOrderPerformance(
                                                    context,
                                                    advanceOrderRevenueTotal,
                                                    completedAdvanceOrdersCount,
                                                    advanceCancellationRate,
                                                    popularAdvanceItems,
                                                  ),
                                                  if (_showEventReservationPerformance) ...[
                                                    const SizedBox(height: AppTheme.lg),
                                                    _buildSectionTitle(
                                                      context,
                                                      'Event Reservation Performance',
                                                    ),
                                                    const SizedBox(height: AppTheme.md),
                                                    _buildEventReservationPerformance(
                                                      context,
                                                      eventReservationRevenueTotal,
                                                      completedEventReservationsCount,
                                                      eventCancellationRate,
                                                      popularEventTypes,
                                                    ),
                                                  ],
                                                ],
                                              )
                                            : Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: _buildAdvanceOrderPerformance(
                                                      context,
                                                      advanceOrderRevenueTotal,
                                                      completedAdvanceOrdersCount,
                                                      advanceCancellationRate,
                                                      popularAdvanceItems,
                                                    ),
                                                  ),
                                                  if (_showEventReservationPerformance) ...[
                                                    const SizedBox(width: AppTheme.lg),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          _buildSectionTitle(
                                                            context,
                                                            'Event Reservation Performance',
                                                          ),
                                                          const SizedBox(
                                                            height: AppTheme.md,
                                                          ),
                                                          _buildEventReservationPerformance(
                                                            context,
                                                            eventReservationRevenueTotal,
                                                            completedEventReservationsCount,
                                                            eventCancellationRate,
                                                            popularEventTypes,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                        const SizedBox(height: 32),
                                        _transactionsSection(tableTransactions, metrics),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
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
            '',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Total Orders',
            data['orders'].toString(),
            Icons.shopping_bag_rounded,
            const Color(0xFF10B981),
            '',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Avg. Order',
            _currencyFormat.format(data['avgOrder']),
            Icons.analytics_rounded,
            const Color(0xFFF59E0B),
            '',
            200,
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Unique Customers',
            data['customers'].toString(),
            Icons.people_alt_rounded,
            const Color(0xFFEC4899),
            '',
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
    return _AnimatedSummaryCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      growth: growth,
      width: width,
    );
  }

  /// ================= CHART CARD =================
  Widget _chartCard(Map<String, List<double>> chartData) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animationValue, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 16 : 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF1F5F9).withValues(alpha: animationValue),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05 * animationValue),
                blurRadius: 20 * animationValue,
                offset: Offset(0, 10 * animationValue),
              ),
            ],
          ),
          transform: Matrix4.identity()
            ..translateByVector3(Vector3(0.0, (1.0 - animationValue) * 20.0, 0.0)),
          child: Opacity(
            opacity: animationValue,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Side-by-side on desktop, stacked on mobile ─────────────
          if (ResponsiveUtils.isMobile(context)) ...[
            // ── Mobile: stacked ──────────────────────────────────────
            // Revenue header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Revenue Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chartTypeButton('Line', Icons.show_chart_rounded),
                      _chartTypeButton('Bar', Icons.bar_chart_rounded),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: selectedChartType == 'Line'
                  ? _buildLineChart(chartData)
                  : _buildBarChart(chartData),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
            const SizedBox(height: 20),
            // Location header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Top Cities/Municipalities by Order Count',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildLocationPeriodFilter(),
              ],
            ),
            const SizedBox(height: 8),
            if (_locationData.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No location data available yet',
                      style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13)),
                ),
              )
            else
              _buildLocationPieChart(),
          ] else ...[
            // ── Desktop: side by side ────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT — Revenue Analytics
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Revenue Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _chartTypeButton('Line', Icons.show_chart_rounded),
                                  _chartTypeButton('Bar', Icons.bar_chart_rounded),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem('Regular Orders', 'Regular', Colors.blue),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 350,
                          child: selectedChartType == 'Line'
                              ? _buildLineChart(chartData)
                              : _buildBarChart(chartData),
                        ),
                      ],
                    ),
                  ),

                  // Vertical divider
                  const SizedBox(width: 24),
                  const VerticalDivider(color: Color(0xFFF1F5F9), thickness: 1.5, width: 1),
                  const SizedBox(width: 24),

                  // RIGHT — Customer Location Forecasting
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                'Top Cities/Municipalities by Order Count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildLocationPeriodFilter(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_locationData.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off_outlined, size: 40, color: AppTheme.mediumGrey),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No location data available yet',
                                    style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          _buildLocationPieChart(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartTypeButton(String type, IconData icon) {
    final isSelected = selectedChartType == type;
    return GestureDetector(
      onTap: () => setState(() => selectedChartType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              type,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateInterval(double maxY) {
    if (maxY <= 0) return 1000.0;
    double rawInterval = maxY / 5.0;
    
    // Find the magnitude (power of 10) of the raw interval
    double log10 = log(rawInterval) / ln10;
    double powerOf10 = pow(10, log10.floor()).toDouble();
    
    double ratio = rawInterval / powerOf10;
    
    double niceRatio;
    if (ratio < 1.5) {
      niceRatio = 1.0;
    } else if (ratio < 3.0) {
      niceRatio = 2.0;
    } else if (ratio < 7.0) {
      niceRatio = 5.0;
    } else {
      niceRatio = 10.0;
    }
    
    return niceRatio * powerOf10;
  }

  Widget _buildLineChart(Map<String, List<double>> chartData) {
    final double lineMaxY = (() {
      double maxVal = 1000.0;
      for (var entry in chartData.entries) {
        final key = entry.key;
        String streamName = '';
        if (key == 'regular') streamName = 'Regular';
        else if (key == 'advance') streamName = 'Advance';
        else if (key == 'reservation') streamName = 'Reservation';
        
        if (activeStreams.contains(streamName)) {
          final list = entry.value;
          if (list.isNotEmpty) {
            final m = list.reduce((a, b) => a > b ? a : b);
            if (m > maxVal) maxVal = m;
          }
        }
      }
      return (maxVal * 1.2).clamp(1000.0, 10000000.0).toDouble();
    })();

    final List<String> labels = getChartLabels();
    final int dataLength = chartData['regular']?.length ?? 0;
    final List<_SalesReportData> chartList = List.generate(dataLength, (i) {
      final label = i < labels.length ? labels[i] : 'Day ${i + 1}';
      final reg = i < chartData['regular']!.length ? chartData['regular']![i] : 0.0;
      final adv = i < chartData['advance']!.length ? chartData['advance']![i] : 0.0;
      final res = i < chartData['reservation']!.length ? chartData['reservation']![i] : 0.0;
      return _SalesReportData(label, reg, adv, res);
    });

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final _SalesReportData item = data;
          final double val = point.y ?? 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.name ?? 'Revenue',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.label}: ${_currencyFormat.format(val)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
        majorGridLines: MajorGridLines(
          color: const Color(0xFFF1F5F9).withOpacity(0.5),
          width: 1,
          dashArray: const [3, 3],
        ),
        maximum: lineMaxY,
      ),
      series: <CartesianSeries<_SalesReportData, String>>[
        if (activeStreams.contains('Regular'))
          SplineSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.regular,
            name: 'Regular Orders',
            color: Colors.blue,
            width: 4,
            animationDuration: 1000,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
              color: Colors.white,
              borderColor: Colors.blue,
              borderWidth: 2,
            ),
          ),
        if (activeStreams.contains('Advance'))
          SplineSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.advance,
            name: 'Advance Orders',
            color: Colors.green,
            width: 4,
            animationDuration: 1000,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
              color: Colors.white,
              borderColor: Colors.green,
              borderWidth: 2,
            ),
          ),
        if (activeStreams.contains('Reservation'))
          SplineSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.reservation,
            name: 'Event Reservations',
            color: Colors.purple,
            width: 4,
            animationDuration: 1000,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
              color: Colors.white,
              borderColor: Colors.purple,
              borderWidth: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildBarChart(Map<String, List<double>> chartData) {
    final double maxCombinedValue = (() {
      double maxVal = 1000.0;
      final regList = chartData['regular'] ?? [];
      final advList = chartData['advance'] ?? [];
      final resList = chartData['reservation'] ?? [];
      for (int i = 0; i < regList.length; i++) {
        double total = 0.0;
        if (activeStreams.contains('Regular')) {
          total += regList[i];
        }
        if (activeStreams.contains('Advance')) {
          total += i < advList.length ? advList[i] : 0.0;
        }
        if (activeStreams.contains('Reservation')) {
          total += i < resList.length ? resList[i] : 0.0;
        }
        if (total > maxVal) {
          maxVal = total;
        }
      }
      return maxVal;
    })();

    final barWidth = ResponsiveUtils.isMobile(context) ? 10.0 : 16.0;

    final List<String> labels = getChartLabels();
    final int dataLength = chartData['regular']?.length ?? 0;
    final List<_SalesReportData> chartList = List.generate(dataLength, (i) {
      final label = i < labels.length ? labels[i] : 'Day ${i + 1}';
      final reg = i < chartData['regular']!.length ? chartData['regular']![i] : 0.0;
      final adv = i < chartData['advance']!.length ? chartData['advance']![i] : 0.0;
      final res = i < chartData['reservation']!.length ? chartData['reservation']![i] : 0.0;
      return _SalesReportData(label, reg, adv, res);
    });

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final _SalesReportData item = data;
          double totalVal = 0.0;
          List<Widget> children = [];

          if (activeStreams.contains('Regular')) {
            totalVal += item.regular;
            children.add(
              Text(
                'Regular: ${_currencyFormat.format(item.regular)}',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
              ),
            );
          }
          if (activeStreams.contains('Advance')) {
            totalVal += item.advance;
            children.add(
              Text(
                'Advance: ${_currencyFormat.format(item.advance)}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
              ),
            );
          }
          if (activeStreams.contains('Reservation')) {
            totalVal += item.reservation;
            children.add(
              Text(
                'Reservation: ${_currencyFormat.format(item.reservation)}',
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...children,
                const Divider(color: Colors.white24, height: 8),
                Text(
                  'Total: ${_currencyFormat.format(totalVal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
        majorGridLines: MajorGridLines(
          color: const Color(0xFFF1F5F9).withOpacity(0.5),
          width: 1,
          dashArray: const [3, 3],
        ),
        maximum: (maxCombinedValue * 1.2).clamp(1000.0, 10000000.0),
      ),
      series: <CartesianSeries<_SalesReportData, String>>[
        if (activeStreams.contains('Regular'))
          StackedColumnSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.regular,
            name: 'Regular Orders',
            color: Colors.blue,
            width: 0.6,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            animationDuration: 1000,
          ),
        if (activeStreams.contains('Advance'))
          StackedColumnSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.advance,
            name: 'Advance Orders',
            color: Colors.green,
            width: 0.6,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            animationDuration: 1000,
          ),
        if (activeStreams.contains('Reservation'))
          StackedColumnSeries<_SalesReportData, String>(
            dataSource: chartList,
            xValueMapper: (_SalesReportData data, _) => data.label,
            yValueMapper: (_SalesReportData data, _) => data.reservation,
            name: 'Event Reservations',
            color: Colors.purple,
            width: 0.6,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            animationDuration: 1000,
          ),
      ],
    );
  }

  Widget _buildLegendItem(String label, String streamKey, Color color) {
    final isActive = activeStreams.contains(streamKey);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isActive) {
            if (activeStreams.length > 1) {
              activeStreams.remove(streamKey);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('At least one data stream must be selected.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            activeStreams.add(streamKey);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.08) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.3) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? color : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: color),
            ]
          ],
        ),
      ),
    );
  }

  Widget _transactionsSection(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
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
                _transactionFilters(transactions, metrics, isVertical: true),
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
                _transactionFilters(transactions, metrics),
              ],
            ),
          const SizedBox(height: 32),
          _transactionsTable(transactions),
        ],
      ),
    );
  }

  Widget _transactionFilters(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics, {bool isVertical = false}) {
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
            _exportToCSV(
              filteredTransactions,
              'Transactions_${_statusFilter.replaceAll(' ', '_')}',
              metrics: metrics,
            );
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
        _exportToCSV(
          filteredTransactions,
          'Transactions_${_statusFilter.replaceAll(' ', '_')}',
          metrics: metrics,
        );
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
      String type = t['type'].toString().toLowerCase();
      String date = t['date'].toString().toLowerCase();
      
      // Search by ID, Customer Name, Transaction Type (Regular, Advance, Reservation), and Date
      bool matchesSearch = id.contains(query) || 
                          customer.contains(query) || 
                          type.contains(query) ||
                          date.contains(query);
          
      return matchesStatus && matchesSearch;
    }).toList();

    // Calculate pagination
    final totalPages = (filteredTransactions.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final paginatedTransactions = filteredTransactions.skip(startIndex).take(_itemsPerPage).toList();

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
                        items: ['All Status', 'Ready', 'Pending', 'Confirmed', 'Cancelled']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _statusFilter = v!;
                            _currentPage = 1; // Reset to first page when filter changes
                          });
                        },
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
                        onChanged: (v) {
                          setState(() {
                            _transactionPeriod = v!;
                            _currentPage = 1; // Reset to first page when filter changes
                          });
                        },
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
                    onChanged: (value) {
                      setState(() {
                        _currentPage = 1; // Reset to first page when search changes
                      });
                    },
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
                  items: ['All Status', 'Ready', 'Pending', 'Confirmed', 'Cancelled']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v!;
                      _currentPage = 1; // Reset to first page when filter changes
                    });
                  },
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
                  onChanged: (v) {
                    setState(() {
                      _transactionPeriod = v!;
                      _currentPage = 1; // Reset to first page when filter changes
                    });
                  },
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
        else
          Column(
            children: [
              if (ResponsiveUtils.isMobile(context))
                ...paginatedTransactions.map((t) => _transactionCard(t))
              else
                Column(
                  children: [
                    _transactionTableHeader(),
                    const Divider(height: 32, color: Color(0xFFF1F5F9)),
                    ...paginatedTransactions.map((t) => _transactionRow(t)),
                  ],
                ),
              const SizedBox(height: 24),
              if (totalPages > 1)
                _paginationControls(totalPages, filteredTransactions.length),
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
        Expanded(flex: 2, child: Text('TYPE', style: style)),
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
            flex: 2,
            child: _typeBadge(t['type'] ?? 'Regular'),
          ),
          Expanded(
            flex: 3,
            child: Builder(
              builder: (context) {
                return _ItemsDisplay(
                  orderId: t['db_id'],
                  type: t['type'] ?? 'Regular',
                  selectedMenuItems: t['selected_menu_items'],
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
              Row(
                children: [
                  _typeBadge(t['type'] ?? 'Regular'),
                  const SizedBox(width: 8),
                  _statusBadge(t['status']),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              return _ItemsDisplay(
                orderId: t['db_id'],
                type: t['type'] ?? 'Regular',
                selectedMenuItems: t['selected_menu_items'],
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

  Widget _typeBadge(String type) {
    Color bg;
    Color textColor;
    String label;
    switch (type) {
      case 'Advance':
        bg = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        label = 'Advance';
        break;
      case 'Reservation':
        bg = const Color(0xFFF3E8FF);
        textColor = const Color(0xFF7C3AED);
        label = 'Event Reservation';
        break;
      default:
        bg = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        label = 'Regular';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
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

  Widget _paginationControls(int totalPages, int totalItems) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final startItem = (_currentPage - 1) * _itemsPerPage + 1;
    final endItem = (_currentPage * _itemsPerPage).clamp(1, totalItems);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Page info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startItem-$endItem of $totalItems transactions',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              if (!isMobile)
                Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Page navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage > 1
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
                  foregroundColor: _currentPage > 1
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  minimumSize: const Size(36, 36),
                ),
              ),
              
              // Page numbers (show max 5 pages)
              if (!isMobile) ...[
                const SizedBox(width: 8),
                ..._buildPageNumbers(totalPages),
                const SizedBox(width: 8),
              ],
              
              // Next button
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage < totalPages
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
                  foregroundColor: _currentPage < totalPages
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
          
          // Mobile page indicator
          if (isMobile)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Page $_currentPage of $totalPages',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    final List<Widget> pageNumbers = [];
    final maxVisiblePages = 5;
    
    int startPage = 1;
    int endPage = totalPages;
    
    if (totalPages > maxVisiblePages) {
      final halfVisible = maxVisiblePages ~/ 2;
      
      if (_currentPage <= halfVisible) {
        endPage = maxVisiblePages;
      } else if (_currentPage >= totalPages - halfVisible) {
        startPage = totalPages - maxVisiblePages + 1;
      } else {
        startPage = _currentPage - halfVisible;
        endPage = _currentPage + halfVisible;
      }
    }
    
    for (int i = startPage; i <= endPage; i++) {
      pageNumbers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: () => setState(() => _currentPage = i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? const Color(0xFF3B82F6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: i == _currentPage
                    ? null
                    : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  '$i',
                  style: TextStyle(
                    color: i == _currentPage
                        ? Colors.white
                        : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: i == _currentPage
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return pageNumbers;
  }

  Widget _buildClickableSectionTitle(
    BuildContext context,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _showEventReservationPerformance
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.sm + 2),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Icon(
              _showEventReservationPerformance
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.sm + 2),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationAnalyticsSection() {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(context, 'Customer Location Forecasting'),
              _buildLocationPeriodFilter(),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (_isLoadingLocationData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
          else if (_locationData.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined, size: 48, color: AppTheme.mediumGrey),
                    SizedBox(height: 16),
                    Text(
                      'No location data available yet',
                      style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Customer addresses from POS orders will appear here',
                      style: TextStyle(color: AppTheme.lightGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Cities/Municipalities by Order Count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationPieChart(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLocationPeriodFilter() {
    final periods = ['All Time', 'Today', 'This Week', 'This Month', 'This Year'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _locationPeriod,
          dropdownColor: Colors.white,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor, size: 16),
          style: const TextStyle(
            color: AppTheme.darkGrey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: periods.map((period) {
            return DropdownMenuItem<String>(
              value: period,
              child: Text(
                period,
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _locationPeriod = value;
              });
              _fetchLocationData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLocationPieChart() {
    final topLocations = _locationData.take(8).toList();
    final totalOrders = topLocations.fold<int>(0, (sum, loc) => sum + (loc['order_count'] as int));
    
    // Define colors for the chart
    final colors = [
      const Color(0xFF4F46E5), // Primary
      const Color(0xFF10B981), // Success Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Error Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF84CC16), // Lime
    ];

    final isMobile = ResponsiveUtils.isMobile(context);
    final chartHeight = isMobile ? 200.0 : 190.0;

    // Reusable 2-Column Legend (IntrinsicHeight-safe layout using Row and Column)
    Widget buildLegendGrid() {
      final List<Widget> rows = [];
      for (int i = 0; i < topLocations.length; i += 2) {
        final location1 = topLocations[i];
        final orderCount1 = location1['order_count'] as int;
        final revenue1 = location1['total_revenue'] as double;
        final color1 = colors[i % colors.length];

        final location2 = (i + 1 < topLocations.length) ? topLocations[i + 1] : null;
        final orderCount2 = location2 != null ? location2['order_count'] as int : 0;
        final revenue2 = location2 != null ? location2['total_revenue'] as double : 0.0;
        final color2 = location2 != null ? colors[(i + 1) % colors.length] : Colors.transparent;

        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color1,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              location1['location'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$orderCount1 orders • ${_currencyFormat.format(revenue1)}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppTheme.mediumGrey,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: location2 != null
                      ? Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    location2['location'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$orderCount2 orders • ${_currencyFormat.format(revenue2)}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppTheme.mediumGrey,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
    }

    return Column(
      children: [
        // Pie Chart
        SizedBox(
          height: chartHeight,
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            series: <CircularSeries<_LocationPieData, String>>[
              DoughnutSeries<_LocationPieData, String>(
                dataSource: topLocations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final location = entry.value;
                  final orderCount = location['order_count'] as int;
                  final percentage = totalOrders > 0 ? (orderCount / totalOrders) : 0.0;
                  return _LocationPieData(
                    location['location']?.toString() ?? '',
                    orderCount.toDouble(),
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    colors[index % colors.length],
                  );
                }).toList(),
                xValueMapper: (_LocationPieData data, _) => data.location,
                yValueMapper: (_LocationPieData data, _) => data.count,
                pointColorMapper: (_LocationPieData data, _) => data.color,
                innerRadius: '60%',
                radius: '95%',
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelPosition: ChartDataLabelPosition.inside,
                  textStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                dataLabelMapper: (_LocationPieData data, _) => data.percentage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        buildLegendGrid(),
      ],
    );
  }

  Widget _buildLocationBarChart() {
    final topLocations = _locationData.take(5).toList();
    
    final double maxY;
    if (topLocations.isEmpty) {
      maxY = 10.0;
    } else {
      final firstOrderCount = topLocations.first['order_count'] as int;
      maxY = (firstOrderCount * 1.2).toDouble();
    }
    
    final double horizontalInterval;
    if (topLocations.isEmpty) {
      horizontalInterval = 2.0;
    } else {
      final firstOrderCount = topLocations.first['order_count'] as int;
      horizontalInterval = ((firstOrderCount / 4).ceil()).toDouble();
    }
    
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
    ];

    final list = topLocations.asMap().entries.map((entry) {
      final index = entry.key;
      final location = entry.value;
      final orderCount = location['order_count'] as int;
      final name = location['location']?.toString() ?? '';
      final displayLabel = name.length > 8 ? '${name.substring(0, 8)}...' : name;
      final color = index < 3 ? colors[index] : AppTheme.primaryColor.withOpacity(0.6);
      return _LocationBarData(
        displayLabel,
        orderCount.toDouble(),
        color,
      );
    }).toList();

    return SizedBox(
      height: 250,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        margin: EdgeInsets.zero,
        tooltipBehavior: TooltipBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
            final _LocationBarData item = data;
            // Get original location name for the tooltip
            final originalName = pointIndex < topLocations.length
                ? topLocations[pointIndex]['location']?.toString() ?? item.location
                : item.location;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$originalName\nOrders: ${item.count.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: const TextStyle(fontSize: 10, color: AppTheme.darkGrey),
          axisLine: const AxisLine(width: 1, color: AppTheme.lightGrey),
        ),
        primaryYAxis: NumericAxis(
          axisLine: const AxisLine(width: 0),
          labelStyle: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey),
          majorGridLines: MajorGridLines(
            color: AppTheme.lightGrey,
            width: 1,
          ),
          maximum: maxY,
        ),
        series: <CartesianSeries<_LocationBarData, String>>[
          ColumnSeries<_LocationBarData, String>(
            dataSource: list,
            xValueMapper: (_LocationBarData data, _) => data.location,
            yValueMapper: (_LocationBarData data, _) => data.count,
            pointColorMapper: (_LocationBarData data, _) => data.color,
            width: 0.5,
            borderRadius: BorderRadius.circular(4),
            animationDuration: 1000,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceOrderPerformance(
    BuildContext context,
    double advanceOrderRevenueTotal,
    int completedAdvanceOrdersCount,
    double advanceCancellationRate,
    Map<String, int> popularAdvanceItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Total AO Revenue',
                '₱${NumberFormat('#,##0.00').format(advanceOrderRevenueTotal)}',
                Icons.account_balance_wallet_outlined,
                AppTheme.primaryColor,
              ),
              _buildStatItem(
                'AO Completed',
                '$completedAdvanceOrdersCount',
                Icons.check_circle_outline,
                AppTheme.successGreen,
              ),
              _buildStatItem(
                'Cancellation Rate',
                '${advanceCancellationRate.toStringAsFixed(1)}%',
                Icons.cancel_outlined,
                AppTheme.errorRed,
              ),
            ],
          ),
          const Divider(height: 40),
          const Text(
            'Popular Advance Order Items',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          if (popularAdvanceItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No completed advance orders yet',
                  style: TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 150, // Fixed height for scrollable list
              child: ListView.builder(
                itemCount: popularAdvanceItems.entries.length,
                itemBuilder: (context, index) {
                  final sortedEntries = popularAdvanceItems.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final e = sortedEntries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${e.value} orders',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildEventReservationPerformance(
    BuildContext context,
    double eventReservationRevenueTotal,
    int completedEventReservationsCount,
    double eventCancellationRate,
    Map<String, int> popularEventTypes,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Total Event Revenue',
                '₱${NumberFormat('#,##0.00').format(eventReservationRevenueTotal)}',
                Icons.event_available_outlined,
                Colors.purple,
              ),
              _buildStatItem(
                'Events Completed',
                '$completedEventReservationsCount',
                Icons.celebration_outlined,
                AppTheme.successGreen,
              ),
              _buildStatItem(
                'Cancellation Rate',
                '${eventCancellationRate.toStringAsFixed(1)}%',
                Icons.cancel_outlined,
                AppTheme.errorRed,
              ),
            ],
          ),
          const Divider(height: 40),
          const Text(
            'Most Popular Event Types',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          if (popularEventTypes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No completed events yet',
                  style: TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (popularEventTypes.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(7)
                  .map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.value.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGrey,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ── Items Display Widget ─────────────────────────────────────────────────────
class _ItemsDisplay extends StatelessWidget {
  final String orderId;
  final String type;
  final Map<String, dynamic>? selectedMenuItems;

  const _ItemsDisplay({
    required this.orderId,
    required this.type,
    this.selectedMenuItems,
  });

  Future<List<Map<String, dynamic>>> _fetchItems() async {
    try {
      final response = await Supabase.instance.client
          .from('order_items')
          .select('item_name, quantity')
          .eq('order_id', orderId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching items: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if ((type == 'Advance' || type == 'Reservation') && selectedMenuItems != null) {
      final itemsStr = selectedMenuItems!.entries
          .map((e) => '${e.key} x${e.value}')
          .join(', ');
      
      return Text(
        itemsStr.isEmpty ? 'No items' : itemsStr,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Loading...',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No items',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          );
        }
        
        final items = snapshot.data!;
        final itemsStr = items
            .map((i) => '${i['item_name']} x${i['quantity']}')
            .join(', ');
        
        return Text(
          itemsStr,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// ── Animated Summary Card Widget ───────────────────────────────────────────────
class _AnimatedSummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String growth;
  final double width;

  const _AnimatedSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.growth,
    required this.width,
  });

  @override
  _AnimatedSummaryCardState createState() => _AnimatedSummaryCardState();
}

class _AnimatedSummaryCardState extends State<_AnimatedSummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: widget.width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.color.withValues(alpha: _isHovered ? 0.3 : 0.1),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.02),
              blurRadius: _isHovered ? 20 : 8,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
            if (_isHovered)
              BoxShadow(
                color: widget.color.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        margin: EdgeInsets.only(
          top: _isHovered ? 4.0 : 0.0,
          bottom: _isHovered ? 0.0 : 4.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _isHovered ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    widget.icon, 
                    color: widget.color, 
                    size: _isHovered ? 22 : 20,
                  ),
                ),
                if (widget.growth.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.growth.contains('+') 
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: _isHovered ? [
                        BoxShadow(
                          color: widget.growth.contains('+') 
                              ? const Color(0xFF16A34A).withOpacity(0.2)
                              : const Color(0xFFDC2626).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      widget.growth,
                      style: TextStyle(
                        color: widget.growth.contains('+') 
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        fontSize: _isHovered ? 11 : 10,
                        fontWeight: _isHovered ? FontWeight.w800 : FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              child: Text(widget.title.toUpperCase()),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: _isHovered ? 22 : 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: _isHovered ? -1.2 : -1,
              ),
              child: Text(widget.value),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated Chart Widget ───────────────────────────────────────────────────
class _AnimatedChart extends StatefulWidget {
  final List<double> chartValues;

  const _AnimatedChart({required this.chartValues});

  @override
  _AnimatedChartState createState() => _AnimatedChartState();
}

class _AnimatedChartState extends State<_AnimatedChart> 
    with TickerProviderStateMixin {
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOutCubic,
    );
    
    // Start chart animation after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _chartController.forward();
      }
    });
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxY = (widget.chartValues.isEmpty 
        ? 1000.0 
        : widget.chartValues.reduce((a, b) => a > b ? a : b) * 1.2)
        .clamp(1000.0, 10000000.0)
        .toDouble();

    final labels = _getChartLabels();
    final list = List.generate(widget.chartValues.length, (i) {
      final label = i < labels.length ? labels[i] : 'Day ${i + 1}';
      return _AnimatedChartData(label, widget.chartValues[i]);
    });

    return SizedBox(
      height: 350,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        margin: EdgeInsets.zero,
        tooltipBehavior: TooltipBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
            final _AnimatedChartData item = data;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(item.value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
          axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
        ),
        primaryYAxis: NumericAxis(
          axisLine: const AxisLine(width: 0),
          labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
          numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
          majorGridLines: MajorGridLines(
            color: const Color(0xFFF1F5F9).withOpacity(0.5),
            width: 1,
            dashArray: const [3, 3],
          ),
          maximum: maxY,
        ),
        series: <CartesianSeries<_AnimatedChartData, String>>[
          SplineSeries<_AnimatedChartData, String>(
            dataSource: list,
            xValueMapper: (_AnimatedChartData data, _) => data.label,
            yValueMapper: (_AnimatedChartData data, _) => data.value,
            color: Colors.red,
            width: 5,
            animationDuration: 1000,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
              color: Colors.white,
              borderColor: Colors.red,
              borderWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getChartLabels() {
    // This would need to be passed from the parent or made accessible
    return ['10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'];
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}m';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(0)}k';
    } else {
      return '₱${value.toStringAsFixed(0)}';
    }
  }
}

class _SalesReportData {
  final String label;
  final double regular;
  final double advance;
  final double reservation;

  _SalesReportData(this.label, this.regular, this.advance, this.reservation);
}

class _LocationPieData {
  final String location;
  final double count;
  final String percentage;
  final Color color;

  _LocationPieData(this.location, this.count, this.percentage, this.color);
}

class _LocationBarData {
  final String location;
  final double count;
  final Color color;

  _LocationBarData(this.location, this.count, this.color);
}

class _AnimatedChartData {
  final String label;
  final double value;

  _AnimatedChartData(this.label, this.value);
}