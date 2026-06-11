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
import 'package:vector_math/vector_math_64.dart' hide Colors;

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
  Set<String> activeStreams = {'Regular', 'Advance', 'Reservation'};
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
    // Combine regular orders, paid advance orders, and paid reservations
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
          final orderHour = date.hour;
          return date.year == now.year && 
              date.month == now.month && 
              date.day == now.day &&
              orderHour >= 10 && orderHour < 20;
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
    
    // Add paid advance orders
    combinedOrders.addAll(allAdvanceOrders.where((order) {
      final date = DateTime.tryParse(order['order_date'] ?? '');
      if (date == null) return false;
      
      // Only include paid advance orders
      final isPaid = order['payment_status'] == 'paid' || order['payment_status'] == 'fully_paid';
      if (!isPaid) return false;
      
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

    // Add paid event reservations
    combinedOrders.addAll(allReservations.where((reservation) {
      final date = DateTime.tryParse(reservation['event_date'] ?? '');
      if (date == null) return false;

      // Filter for paid/fully_paid/deposit_paid events
      final paymentStatus = reservation['payment_status']?.toString() ?? '';
      final isPaid = paymentStatus == 'paid' ||
          paymentStatus == 'fully_paid' ||
          paymentStatus == 'deposit_paid';
      if (!isPaid) return false;

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
    }).map((r) {
      // Map event reservations so they are recognizable as reservations
      return {
        ...r,
        'is_reservation': true,
      };
    }).toList());
    
    if (combinedOrders.isEmpty) {
      return {'revenue': 0.0, 'orders': 0, 'customers': 0, 'avgOrder': 0.0};
    }

    double totalRevenue = 0;
    Set<String> uniqueCustomers = {};

    for (var order in combinedOrders) {
      double amount = 0.0;
      if (order['is_reservation'] == true) {
        final paymentStatus = order['payment_status']?.toString() ?? '';
        if (paymentStatus == 'deposit_paid') {
          amount = (order['deposit_amount'] as num?)?.toDouble() ?? 
                   ((order['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
        } else {
          amount = (order['total_price'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        amount = order.containsKey('total_amount') 
            ? (order['total_amount'] as num?)?.toDouble() ?? 0.0
            : (order['total_price'] as num?)?.toDouble() ?? 0.0;
      }
      totalRevenue += amount;
      uniqueCustomers.add(order['customer_name'] ?? 'Guest');
    }

    return {
      'revenue': totalRevenue,
      'orders': combinedOrders.length,
      'customers': uniqueCustomers.length,
      'avgOrder': totalRevenue / combinedOrders.length,
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

    // Helper to process regular orders
    for (var order in orders) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) continue;

      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      _addToPeriodData(date, amount, regularData, now);
    }

    // Helper to process advance orders
    for (var order in advanceOrders) {
      final date = DateTime.tryParse(order['order_date'] ?? '');
      if (date == null) continue;

      final isPaid = order['payment_status'] == 'paid' || order['payment_status'] == 'fully_paid';
      if (!isPaid) continue;

      final amount = (order['total_price'] as num?)?.toDouble() ?? 0.0;
      _addToPeriodData(date, amount, advanceData, now, isAdvance: true, advanceOrder: order);
    }

    // Helper to process event reservations
    for (var reservation in reservations) {
      final date = DateTime.tryParse(reservation['event_date'] ?? '');
      if (date == null) continue;

      final paymentStatus = reservation['payment_status']?.toString() ?? '';
      final isPaid = paymentStatus == 'paid' ||
          paymentStatus == 'fully_paid' ||
          paymentStatus == 'deposit_paid';
      if (!isPaid) continue;

      double amount = 0.0;
      if (paymentStatus == 'deposit_paid') {
        amount = (reservation['deposit_amount'] as num?)?.toDouble() ?? 
                 ((reservation['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
      } else {
        amount = (reservation['total_price'] as num?)?.toDouble() ?? 0.0;
      }
      _addToPeriodData(date, amount, reservationData, now, isReservation: true, reservation: reservation);
    }

    int length = 0;
    if (selectedPeriod == 'Daily') {
      length = 11;
    } else if (selectedPeriod == 'Weekly') {
      length = 7;
    } else if (selectedPeriod == 'Monthly') {
      length = 12;
    } else {
      length = now.year - 2016 + 1;
    }

    return {
      'regular': List.generate(length, (i) => regularData[i] ?? 0.0),
      'advance': List.generate(length, (i) => advanceData[i] ?? 0.0),
      'reservation': List.generate(length, (i) => reservationData[i] ?? 0.0),
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
            date.day == now.day) {
           if (isAdvance && advanceOrder != null) {
             try {
                final timeStr = advanceOrder['order_time']?.toString() ?? '12:00 PM';
                final hour = DateFormat.jm().parse(timeStr).hour;
                if (hour >= 10 && hour < 20) {
                  final key = hour - 10;
                  periodData[key] = (periodData[key] ?? 0) + amount;
                }
             } catch (_) {
                periodData[2] = (periodData[2] ?? 0) + amount; // Fallback to 12 PM
             }
           } else if (isReservation && reservation != null) {
             try {
                final timeStr = reservation['start_time']?.toString() ?? '12:00 PM';
                final hour = DateFormat.jm().parse(timeStr).hour;
                if (hour >= 10 && hour < 20) {
                  final key = hour - 10;
                  periodData[key] = (periodData[key] ?? 0) + amount;
                }
             } catch (_) {
                periodData[2] = (periodData[2] ?? 0) + amount; // Fallback to 12 PM
             }
           } else {
              final orderHour = date.hour;
              if (orderHour >= 10 && orderHour < 20) {
                final key = orderHour - 10;
                periodData[key] = (periodData[key] ?? 0) + amount;
              }
           }
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
                        final isBusinessHours = now.hour >= 10 && now.hour < 20; // 10:00 AM to 8: PM
                        
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
            'Active Customers',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem('Regular Orders', 'Regular', Colors.blue),
                        _buildLegendItem('Advance Orders', 'Advance', Colors.green),
                        _buildLegendItem('Event Reservations', 'Reservation', Colors.purple),
                      ],
                    ),
                  ],
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
          const SizedBox(height: 40),
          SizedBox(
            height: ResponsiveUtils.isMobile(context) ? 260 : 350,
            child: selectedChartType == 'Line'
                ? _buildLineChart(chartData)
                : _buildBarChart(chartData),
          ),
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
    if (maxY <= 0) return 1000;
    double rawInterval = maxY / 5;
    if (rawInterval < 100) return 100;
    if (rawInterval < 500) return 500;
    if (rawInterval < 1000) return 1000;
    if (rawInterval < 5000) return 5000;
    if (rawInterval < 10000) return 10000;
    if (rawInterval < 50000) return 50000;
    if (rawInterval < 100000) return 100000;
    return (rawInterval / 50000).round() * 50000.0;
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

    return LineChart(
      LineChartData(
        maxY: lineMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipPadding: const EdgeInsets.all(12),
            getTooltipItems: (spots) {
              // Build the ordered list of ACTIVE stream names exactly as
              // they were added to lineBarsData (Regular → Advance → Reservation).
              // This ensures barIndex always maps to the correct stream name
              // regardless of which streams are currently toggled on/off.
              final List<String> activeLineNames = [];
              if (activeStreams.contains('Regular')) activeLineNames.add('Regular Orders');
              if (activeStreams.contains('Advance')) activeLineNames.add('Advance Orders');
              if (activeStreams.contains('Reservation')) activeLineNames.add('Event Reservations');

              return spots.map((spot) {
                final labels = getChartLabels();
                final dayIndex = spot.x.toInt();
                final dayLabel = dayIndex < labels.length 
                    ? labels[dayIndex] 
                    : 'Day ${dayIndex + 1}';

                // Use the ordered active names list; fall back gracefully
                final lineName = spot.barIndex < activeLineNames.length
                    ? activeLineNames[spot.barIndex]
                    : 'Revenue';

                return LineTooltipItem(
                  '$lineName: ${_currencyFormat.format(spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: '\n$dayLabel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final labels = getChartLabels();
                final dayIndex = value.toInt();
                
                final firstList = chartData.values.first;
                if (dayIndex >= firstList.length || dayIndex < 0) {
                  return const SizedBox.shrink();
                }
                
                if (dayIndex < labels.length) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      labels[dayIndex],
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
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
              interval: _calculateInterval(lineMaxY),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatCurrency(value),
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
              reservedSize: 50,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(lineMaxY),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFF1F5F9).withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: const Color(0xFFF1F5F9).withOpacity(0.5),
            width: 1,
          ),
        ),
        lineBarsData: [
          // Regular Orders
          if (activeStreams.contains('Regular'))
            LineChartBarData(
              spots: List.generate(
                chartData['regular']!.length,
                (i) => FlSpot(i.toDouble(), chartData['regular']![i]),
              ),
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.08),
              ),
            ),
          // Advance Orders
          if (activeStreams.contains('Advance'))
            LineChartBarData(
              spots: List.generate(
                chartData['advance']!.length,
                (i) => FlSpot(i.toDouble(), chartData['advance']![i]),
              ),
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.green,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.08),
              ),
            ),
          // Event Reservations
          if (activeStreams.contains('Reservation'))
            LineChartBarData(
              spots: List.generate(
                chartData['reservation']!.length,
                (i) => FlSpot(i.toDouble(), chartData['reservation']![i]),
              ),
              isCurved: true,
              color: Colors.purple,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.purple,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.purple.withOpacity(0.08),
              ),
            ),
        ],
        minY: 0,
      ),
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

    return BarChart(
      BarChartData(
        maxY: (maxCombinedValue * 1.2).clamp(1000.0, 10000000.0),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipPadding: const EdgeInsets.all(12),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final labels = getChartLabels();
              final label = groupIndex < labels.length 
                  ? labels[groupIndex] 
                  : 'Day ${groupIndex + 1}';
              
              double regularVal = 0.0;
              double advanceVal = 0.0;
              double reservationVal = 0.0;
              
              if (groupIndex < chartData['regular']!.length) {
                regularVal = chartData['regular']![groupIndex];
              }
              if (groupIndex < chartData['advance']!.length) {
                advanceVal = chartData['advance']![groupIndex];
              }
              if (groupIndex < chartData['reservation']!.length) {
                reservationVal = chartData['reservation']![groupIndex];
              }
              
              double totalVal = 0.0;
              List<TextSpan> breakdownSpans = [];
              
              if (activeStreams.contains('Regular')) {
                totalVal += regularVal;
                breakdownSpans.add(TextSpan(
                  text: 'Regular: ${_currencyFormat.format(regularVal)}\n',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ));
              }
              if (activeStreams.contains('Advance')) {
                totalVal += advanceVal;
                breakdownSpans.add(TextSpan(
                  text: 'Advance: ${_currencyFormat.format(advanceVal)}\n',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ));
              }
              if (activeStreams.contains('Reservation')) {
                totalVal += reservationVal;
                breakdownSpans.add(TextSpan(
                  text: 'Reservation: ${_currencyFormat.format(reservationVal)}\n',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ));
              }

              return BarTooltipItem(
                '$label\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: [
                  ...breakdownSpans,
                  TextSpan(
                    text: 'Total: ${_currencyFormat.format(totalVal)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final labels = getChartLabels();
                final index = value.toInt();
                if (index >= labels.length || index < 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    labels[index],
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _calculateInterval(maxCombinedValue * 1.2),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatCurrency(value),
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
              reservedSize: 50,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(maxCombinedValue * 1.2),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFF1F5F9).withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [3, 3],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          chartData['regular']!.length,
          (index) {
            final reg = chartData['regular']![index];
            final adv = chartData['advance']![index];
            final res = chartData['reservation']![index];
            
            double currentY = 0.0;
            List<BarChartRodStackItem> stackItems = [];
            
            if (activeStreams.contains('Regular')) {
              stackItems.add(BarChartRodStackItem(currentY, currentY + reg, Colors.blue));
              currentY += reg;
            }
            if (activeStreams.contains('Advance')) {
              stackItems.add(BarChartRodStackItem(currentY, currentY + adv, Colors.green));
              currentY += adv;
            }
            if (activeStreams.contains('Reservation')) {
              stackItems.add(BarChartRodStackItem(currentY, currentY + res, Colors.purple));
              currentY += res;
            }
            
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: currentY,
                  width: barWidth,
                  borderRadius: BorderRadius.circular(6),
                  rodStackItems: stackItems,
                ),
              ],
            );
          },
        ),
      ),
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
                        items: ['All Status', 'Ready', 'Pending', 'Cancelled']
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
                  items: ['All Status', 'Ready', 'Pending', 'Cancelled']
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
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return SizedBox(
          height: 350,
          child: LineChart(
            LineChartData(
              maxY: (widget.chartValues.isEmpty ? 1000.0 : widget.chartValues.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, 10000000.0).toDouble(),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E293B),
                  tooltipPadding: const EdgeInsets.all(12),
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final labels = _getChartLabels();
                      final dayIndex = spot.x.toInt();
                      final dayLabel = dayIndex < labels.length 
                          ? labels[dayIndex] 
                          : 'Day ${dayIndex + 1}';
                      
                      return LineTooltipItem(
                        NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(spot.y),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: '\n$dayLabel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final labels = _getChartLabels();
                      final dayIndex = value.toInt();
                      
                      if (dayIndex >= widget.chartValues.length || dayIndex < 0) {
                        return const SizedBox.shrink();
                      }
                      
                      if (dayIndex < labels.length) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            labels[dayIndex],
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
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
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold),
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
                drawVerticalLine: true,
                horizontalInterval: 1000,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFF1F5F9).withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: const Color(0xFFF1F5F9).withOpacity(0.3),
                  strokeWidth: 1,
                  dashArray: [2, 4],
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: const Color(0xFFF1F5F9).withOpacity(0.5),
                  width: 1,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    widget.chartValues.length,
                    (i) => FlSpot(i.toDouble(), widget.chartValues[i] * _chartAnimation.value),
                  ),
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.red,
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.red.withValues(alpha: 0.3 * _chartAnimation.value),
                  ),
                ),
              ],
              minY: 0,
            ),
          ),
        );
      },
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