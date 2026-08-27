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
  String selectedChartType = 'Area'; // 'Area', 'Bar'
  Set<String> activeStreams = {'Regular', 'Advance', 'Reservation'};
  bool _showEventReservationPerformance = true;
  final _supabase = Supabase.instance.client;
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All Status';
  String _channelFilter = 'All Channels';
  String _transactionPeriod = 'All Time';
  
  late Stream<List<Map<String, dynamic>>> _ordersStreamVar;
  late Stream<List<Map<String, dynamic>>> _inventoryStreamVar;
  late Stream<List<Map<String, dynamic>>> _advanceOrdersStreamVar;
  late Stream<List<Map<String, dynamic>>> _reservationsStreamVar;
  Timer? _refreshTimer;
  
  // Location analytics
  final LocationAnalyticsService _locationAnalyticsService = LocationAnalyticsService();
  List<Map<String, dynamic>> _locationData = [];
  String _locationPeriod = 'All Time';

  // Pagination state
  int _currentPage = 1;
  final int _itemsPerPage = 8;

  // FocusNodes for DropdownButtons
  final FocusNode _periodDropdownFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _yearDropdownFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _statusDropdownFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _channelDropdownFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _transactionPeriodFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _locationPeriodFocusNode = FocusNode(canRequestFocus: false);

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    
    _ordersStreamVar = _ordersStream();
    _inventoryStreamVar = _inventoryStream();
    _advanceOrdersStreamVar = _advanceOrdersStream();
    _reservationsStreamVar = _reservationsStream();
    
    _fetchLocationData();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchLocationData();
        setState(() {});
      }
    });
    
    _searchController.addListener(() {
      if (mounted) setState(() => _currentPage = 1);
    });
  }

  Future<void> _fetchLocationData() async {
    if (!mounted) return;

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

      final data = await _locationAnalyticsService.getTopLocationsByRevenue(
        limit: 8,
        startDate: startDate,
        endDate: endDate,
      );
      
      if (mounted) {
        setState(() {
          _locationData = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching location data: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _refreshTimer?.cancel();
    _periodDropdownFocusNode.dispose();
    _yearDropdownFocusNode.dispose();
    _statusDropdownFocusNode.dispose();
    _channelDropdownFocusNode.dispose();
    _transactionPeriodFocusNode.dispose();
    _locationPeriodFocusNode.dispose();
    super.dispose();
  }

  String _formatTransactionRef(dynamic rawTxnId, dynamic rawDbId, String type) {
    String raw = (rawTxnId ?? rawDbId ?? '').toString().trim();
    if (raw.isEmpty) return '#N/A';

    // Strip leading # if already present
    if (raw.startsWith('#')) raw = raw.substring(1).trim();

    // Strip existing prefix tags if redundant
    if (raw.toUpperCase().startsWith('AO-')) raw = raw.substring(3).trim();
    if (raw.toUpperCase().startsWith('RES-')) raw = raw.substring(4).trim();
    if (raw.toUpperCase().startsWith('ORD-')) raw = raw.substring(4).trim();

    String prefix = '';
    if (type == 'Advance') {
      prefix = 'AO-';
    } else if (type == 'Reservation') {
      prefix = 'RES-';
    } else {
      // Regular walk-in order
      final isNumeric = RegExp(r'^\d+$').hasMatch(raw);
      prefix = isNumeric ? '' : 'ORD-';
    }

    // If UUID (contains hyphens or is a 32+ hex string), use first 8 characters
    if (raw.contains('-') || raw.length >= 32) {
      final cleanHex = raw.replaceAll('-', '');
      final shortHex = cleanHex.length >= 8 ? cleanHex.substring(0, 8).toUpperCase() : cleanHex.toUpperCase();
      return '#$prefix$shortHex';
    }

    // If numeric or custom string is long (e.g. timestamp > 10 chars), truncate to 8 chars
    if (raw.length > 10) {
      final shortPart = raw.substring(raw.length - 8);
      return '#$prefix$shortPart';
    }

    return '#$prefix$raw';
  }

  String _resolveProcessedBy(Map<String, dynamic> item, String channel) {
    if (item['cashier_name'] != null && item['cashier_name'].toString().trim().isNotEmpty) {
      return item['cashier_name'].toString().trim();
    }
    if (item['processed_by'] != null && item['processed_by'].toString().trim().isNotEmpty) {
      return item['processed_by'].toString().trim();
    }
    if (item['server_name'] != null && item['server_name'].toString().trim().isNotEmpty) {
      return item['server_name'].toString().trim();
    }
    if (item['staff_name'] != null && item['staff_name'].toString().trim().isNotEmpty) {
      return item['staff_name'].toString().trim();
    }
    if (item['approved_by'] != null && item['approved_by'].toString().trim().isNotEmpty) {
      return item['approved_by'].toString().trim();
    }
    if (item['reviewed_by'] != null && item['reviewed_by'].toString().trim().isNotEmpty) {
      return item['reviewed_by'].toString().trim();
    }
    if (item['actor_name'] != null && item['actor_name'].toString().trim().isNotEmpty) {
      return item['actor_name'].toString().trim();
    }
    if (item['staff_email'] != null && item['staff_email'].toString().trim().isNotEmpty) {
      final email = item['staff_email'].toString().trim();
      if (email.toLowerCase().contains('staffycp')) return 'staffycp@gmail.com';
      if (email.toLowerCase().contains('admn.pagsanjan') || email.toLowerCase().contains('pagsanjan')) return 'admn.pagsanjan@gmail.com';
      if (email.toLowerCase() == 'staff') return 'staffycp@gmail.com';
      if (email.toLowerCase() == 'admin') return 'admn.pagsanjan@gmail.com';
      return email;
    }
    if (channel == 'Regular') return 'staffycp@gmail.com';
    if (channel == 'Advance') return 'admn.pagsanjan@gmail.com';
    if (channel == 'Reservation') return 'admn.pagsanjan@gmail.com';
    return 'staffycp@gmail.com';
  }

  Map<String, dynamic> _processMetrics(
      List<Map<String, dynamic>> allOrders,
      List<Map<String, dynamic>> allAdvanceOrders,
      List<Map<String, dynamic>> allReservations) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    bool isDateInSelectedPeriod(DateTime? rawDate) {
      if (rawDate == null) return false;
      final date = rawDate.toLocal();
      if (selectedPeriod != 'Annually' && date.year.toString() != selectedYear) {
        return false;
      }
      switch (selectedPeriod) {
        case 'Daily':
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case 'Weekly':
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && date.isBefore(endOfWeek);
        case 'Monthly':
          return date.year.toString() == selectedYear;
        case 'Annually':
          return date.year >= 2020 && date.year <= now.year;
        default:
          return false;
      }
    }

    double regularRevenue = 0;
    int regularOrdersCount = 0;
    Set<String> uniqueCustomers = {};

    for (var order in allOrders) {
      final rawDate = DateTime.tryParse(order['created_at'] ?? '');
      if (isDateInSelectedPeriod(rawDate)) {
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 
                       (order['total_price'] as num?)?.toDouble() ?? 0.0;
        regularRevenue += amount;
        regularOrdersCount++;
        final name = order['customer_name']?.toString() ?? '';
        if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
      }
    }

    double advanceRevenue = 0;
    int advanceOrdersCount = 0;
    for (var adv in allAdvanceOrders) {
      final rawDate = DateTime.tryParse(adv['order_date'] ?? '');
      if (isDateInSelectedPeriod(rawDate)) {
        final status = (adv['status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (adv['payment_status']?.toString() ?? '').toLowerCase();
        final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
        if (isPaid || status == 'completed' || status == 'done' || status == 'ready') {
          advanceRevenue += (adv['total_price'] as num?)?.toDouble() ?? 0.0;
          advanceOrdersCount++;
          final name = adv['customer_name']?.toString() ?? '';
          if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
        }
      }
    }

    double reservationRevenue = 0;
    int reservationOrdersCount = 0;
    for (var res in allReservations) {
      final rawDate = DateTime.tryParse(res['event_date'] ?? '');
      if (isDateInSelectedPeriod(rawDate)) {
        final status = (res['status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (res['payment_status']?.toString() ?? '').toLowerCase();
        if (paymentStatus == 'deposit_paid') {
          final amt = (res['deposit_amount'] as num?)?.toDouble() ?? 
                     ((res['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
          reservationRevenue += amt;
          reservationOrdersCount++;
        } else if (paymentStatus == 'paid' || paymentStatus == 'fully_paid' || status == 'confirmed' || status == 'completed') {
          final amt = (res['total_price'] as num?)?.toDouble() ?? 0.0;
          reservationRevenue += amt;
          reservationOrdersCount++;
        }
        final name = res['customer_name']?.toString() ?? '';
        if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
      }
    }

    final totalRevenue = regularRevenue + advanceRevenue + reservationRevenue;
    final totalOrders = regularOrdersCount + advanceOrdersCount + reservationOrdersCount;
    final avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    return {
      'revenue': totalRevenue,
      'regularRevenue': regularRevenue,
      'advanceRevenue': advanceRevenue,
      'reservationRevenue': reservationRevenue,
      'orders': totalOrders,
      'regularOrders': regularOrdersCount,
      'advanceOrders': advanceOrdersCount,
      'reservationOrders': reservationOrdersCount,
      'customers': uniqueCustomers.length,
      'avgOrder': avgOrder,
    };
  }

  DateTime? _parseDateWithTime(String? dateStr, String? timeStr, String? createdAtStr) {
    if (dateStr == null || dateStr.isEmpty) {
      if (createdAtStr != null && createdAtStr.isNotEmpty) {
        return DateTime.tryParse(createdAtStr)?.toLocal();
      }
      return null;
    }
    
    if (dateStr.contains('T')) {
      return DateTime.tryParse(dateStr)?.toLocal();
    }

    DateTime? parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate == null) return null;

    if (timeStr != null && timeStr.isNotEmpty) {
      try {
        final cleanTime = timeStr.trim();
        int hour = 0;
        int minute = 0;
        if (cleanTime.toLowerCase().contains('pm') || cleanTime.toLowerCase().contains('am')) {
          final isPm = cleanTime.toLowerCase().contains('pm');
          final parts = cleanTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
          hour = int.parse(parts[0]);
          if (isPm && hour < 12) hour += 12;
          if (!isPm && hour == 12) hour = 0;
          if (parts.length > 1) minute = int.parse(parts[1]);
        } else if (cleanTime.contains(':')) {
          final parts = cleanTime.split(':');
          hour = int.parse(parts[0]);
          if (parts.length > 1) minute = int.parse(parts[1]);
        }
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
      } catch (_) {}
    }

    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final created = DateTime.tryParse(createdAtStr)?.toLocal();
      if (created != null && created.year == parsedDate.year && created.month == parsedDate.month && created.day == parsedDate.day) {
        return created;
      }
    }

    return parsedDate;
  }

  Map<String, List<double>> _processChartData(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> advanceOrders,
      List<Map<String, dynamic>> reservations) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    Map<int, double> regularData = {};
    Map<int, double> advanceData = {};
    Map<int, double> reservationData = {};

    void addPoint(DateTime? date, double amount, Map<int, double> target) {
      if (date == null) return;

      switch (selectedPeriod) {
        case 'Daily':
          if (date.year == now.year && date.month == now.month && date.day == now.day) {
            // Hours 9 AM to 9 PM (9:00 - 21:00)
            int hourIndex = date.hour - 9;
            if (hourIndex < 0) hourIndex = 0;
            if (hourIndex > 12) hourIndex = 12;
            target[hourIndex] = (target[hourIndex] ?? 0) + amount;
          }
          break;
        case 'Weekly':
          if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && date.isBefore(endOfWeek)) {
            final key = (date.weekday - 1).clamp(0, 6); // 0: Mon ... 6: Sun
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
        case 'Monthly':
          if (date.year.toString() == selectedYear) {
            final key = (date.month - 1).clamp(0, 11);
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
        case 'Annually':
          if (date.year >= 2020 && date.year <= now.year) {
            final key = date.year - 2020;
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
      }
    }

    // 1. Regular Walk-in Orders
    for (var o in orders) {
      final date = DateTime.tryParse(o['created_at'] ?? '')?.toLocal();
      final amt = (o['total_amount'] as num?)?.toDouble() ?? 
                  (o['total_price'] as num?)?.toDouble() ?? 0.0;
      addPoint(date, amt, regularData);
    }

    // 2. Advance Orders
    for (var adv in advanceOrders) {
      final status = (adv['status']?.toString() ?? '').toLowerCase();
      final paymentStatus = (adv['payment_status']?.toString() ?? '').toLowerCase();
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
      if (isPaid || status == 'completed' || status == 'done' || status == 'ready') {
        final date = _parseDateWithTime(adv['order_date'], adv['order_time'], adv['created_at']);
        final amt = (adv['total_price'] as num?)?.toDouble() ?? 0.0;
        addPoint(date, amt, advanceData);
      }
    }

    // 3. Event Reservations
    for (var res in reservations) {
      final status = (res['status']?.toString() ?? '').toLowerCase();
      final pStatus = (res['payment_status']?.toString() ?? '').toLowerCase();
      if (pStatus == 'deposit_paid' || pStatus == 'paid' || pStatus == 'fully_paid' || status == 'confirmed' || status == 'completed') {
        final date = _parseDateWithTime(res['event_date'], res['start_time'], res['created_at']);
        double amt = 0.0;
        if (pStatus == 'deposit_paid') {
          amt = (res['deposit_amount'] as num?)?.toDouble() ?? 
                ((res['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
        } else {
          amt = (res['total_price'] as num?)?.toDouble() ?? 0.0;
        }
        addPoint(date, amt, reservationData);
      }
    }

    int length = 12;
    if (selectedPeriod == 'Daily') {
      length = 13; // 9:00 AM to 9:00 PM (13 slots)
    } else if (selectedPeriod == 'Weekly') {
      length = 7;
    } else if (selectedPeriod == 'Monthly') {
      length = 12;
    } else {
      length = now.year - 2020 + 1;
    }

    return {
      'regular': List.generate(length, (i) => regularData[i] ?? 0.0),
      'advance': List.generate(length, (i) => advanceData[i] ?? 0.0),
      'reservation': List.generate(length, (i) => reservationData[i] ?? 0.0),
    };
  }

  List<String> getChartLabels() {
    if (selectedPeriod == 'Daily') {
      return ['9 AM', '10 AM', '11 AM', '12 PM', '1 PM', '2 PM', '3 PM', '4 PM', '5 PM', '6 PM', '7 PM', '8 PM', '9 PM'];
    } else if (selectedPeriod == 'Weekly') {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (selectedPeriod == 'Monthly') {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    } else {
      final nowYear = DateTime.now().year;
      return List.generate(nowYear - 2020 + 1, (i) => (2020 + i).toString());
    }
  }

  Future<void> _exportToCSV(List<Map<String, dynamic>> transactions, String fileName, {Map<String, dynamic>? metrics}) async {
    if (transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions to export for the selected period.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.adminPrimaryAccent),
                  SizedBox(height: 16),
                  Text('Generating Sales Ledger CSV...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

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

      if (mounted) Navigator.pop(context);

      List<List<dynamic>> rows = [];

      rows.add(['YANG CHOW RESTAURANT & CATERING - OFFICIAL SALES REPORT']);
      rows.add(['Report Period', '${selectedPeriod.toUpperCase()} ($selectedYear)']);
      rows.add(['Generated At', DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now())]);
      rows.add([]);

      if (metrics != null) {
        rows.add(['EXECUTIVE FINANCIAL SUMMARY']);
        rows.add(['Gross Revenue', _currencyFormat.format(metrics['revenue']).replaceAll('₱', 'PHP ')]);
        rows.add(['Walk-in Revenue', _currencyFormat.format(metrics['regularRevenue']).replaceAll('₱', 'PHP ')]);
        rows.add(['Advance Orders Revenue', _currencyFormat.format(metrics['advanceRevenue']).replaceAll('₱', 'PHP ')]);
        rows.add(['Event Catering Revenue', _currencyFormat.format(metrics['reservationRevenue']).replaceAll('₱', 'PHP ')]);
        rows.add(['Total Orders Completed', metrics['orders']]);
        rows.add(['Average Order Value (AOV)', _currencyFormat.format(metrics['avgOrder']).replaceAll('₱', 'PHP ')]);
        rows.add(['Unique Customers', metrics['customers']]);
        rows.add(['Low Stock Inventory Items', metrics['lowStock']]);
        rows.add([]);
      }

      rows.add(['TRANSACTION AUDIT LOG']);
      rows.add(['Transaction Ref', 'Database ID', 'Processed By', 'Customer Name', 'Sales Channel', 'Payment Method', 'Ordered Items', 'Date & Time', 'Amount (PHP)', 'Status']);

      for (var t in transactions) {
        String itemsStr = 'No items';
        if ((t['type'] == 'Advance' || t['type'] == 'Reservation') && t['selected_menu_items'] != null) {
          final Map<String, dynamic> items = Map<String, dynamic>.from(t['selected_menu_items']);
          itemsStr = items.entries.map((e) => '${e.key} x${e.value}').join('; ');
        } else {
          itemsStr = itemsMap[t['db_id']] ?? 'No items';
        }

        rows.add([
          t['id'],
          t['db_id'] ?? t['raw_id'] ?? '',
          t['processed_by'] ?? 'POS Staff / Admin',
          t['customer'],
          t['type'],
          t['payment_method'] ?? 'N/A',
          itemsStr,
          t['full_date'] ?? t['date'],
          t['raw_amount']?.toString() ?? t['amount'].toString().replaceAll('₱', '').replaceAll(',', ''),
          t['status'],
        ]);
      }

      String csvData = csv_pkg.CsvCodec().encode(rows);
      final Uint8List bytes = utf8.encode(csvData);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow Sales Report CSV',
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
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Sales report saved successfully: $fileName.csv')),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showReceiptModal(BuildContext context, Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = ResponsiveUtils.isMobile(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.adminSidebarBackground.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppTheme.adminSidebarBackground, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Yang Chow Restaurant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText), overflow: TextOverflow.ellipsis),
                                  Text('Sales Transaction Voucher', style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.mediumGrey),
                      ),
                    ],
                  ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 16),

              // Transaction Meta Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.adminMainBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    _buildModalRow(
                      'Transaction Ref:', 
                      transaction['id'] ?? '#N/A', 
                      isBold: true,
                      subValue: transaction['db_id'] != null && transaction['db_id'] != transaction['id'] 
                          ? 'DB ID: ${transaction['db_id']}' 
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _buildModalRow('Processed By:', transaction['processed_by'] ?? 'POS Staff / Admin', isProcessedBy: true),
                    const SizedBox(height: 8),
                    _buildModalRow('Customer Name:', transaction['customer'] ?? 'Guest'),
                    const SizedBox(height: 8),
                    _buildModalRow('Sales Channel:', transaction['type'] ?? 'Regular'),
                    if (transaction['payment_method'] != null && transaction['payment_method'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Payment Method:', transaction['payment_method']),
                    ],
                    const SizedBox(height: 8),
                    _buildModalRow('Date & Time:', transaction['full_date'] ?? transaction['date'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildModalRow('Order Status:', transaction['status'] ?? 'Completed', isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Itemized details
              const Text('ORDER ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.adminSecondaryText)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      if ((transaction['type'] == 'Advance' || transaction['type'] == 'Reservation') && transaction['selected_menu_items'] != null) {
                        final Map<String, dynamic> items = Map<String, dynamic>.from(transaction['selected_menu_items']);
                        if (items.isEmpty) return const Text('No items specified', style: TextStyle(color: AppTheme.mediumGrey, fontSize: 12));
                        return Column(
                          children: items.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Text('x${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.adminSecondaryText)),
                              ],
                            ),
                          )).toList(),
                        );
                      }

                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchOrderItems(transaction['db_id'] ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)));
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return const Text('Standard Walk-in Order Items', style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey));
                          }
                          return Column(
                            children: items.map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(i['item_name'] ?? 'Item', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  Text('x${i['quantity'] ?? 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.adminSecondaryText)),
                                ],
                              ),
                            )).toList(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 16),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Net Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText)),
                  Text(
                    transaction['amount'] ?? '₱0.00',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.adminSidebarBackground),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  label: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminSidebarBackground,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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

  Future<List<Map<String, dynamic>>> _fetchOrderItems(String orderId) async {
    if (orderId.isEmpty) return [];
    try {
      final res = await _supabase
          .from('order_items')
          .select('item_name, quantity')
          .eq('order_id', orderId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Widget _buildModalRow(
    String label, 
    String value, {
    bool isBold = false, 
    bool isStatus = false,
    bool isProcessedBy = false,
    String? subValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500)),
        if (isStatus)
          _statusBadge(value)
        else if (isProcessedBy)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.adminSidebarBackground.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.adminSidebarBackground.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_pin_rounded, size: 13, color: AppTheme.adminSidebarBackground),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.adminSidebarBackground),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: AppTheme.adminPrimaryText,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey, fontFamily: 'monospace'),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
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

                        final lowStockCount = allInventory.where((item) {
                          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                          return qty < 10;
                        }).length;
                        metrics['lowStock'] = lowStockCount;

                        // Calculate Advance Order Performance Metrics
                        final double advanceOrderRevenueTotal = allAdvanceOrders
                            .where((o) => o['payment_status'] == 'paid' || o['payment_status'] == 'fully_paid')
                            .fold(0.0, (sum, o) => sum + ((o['total_price'] as num?)?.toDouble() ?? 0.0));

                        final int completedAdvanceOrdersCount = allAdvanceOrders
                            .where((o) => o['status'] == 'done' || o['status'] == 'completed' || o['status'] == 'ready')
                            .length;

                        final int cancelledAdvanceOrdersCount = allAdvanceOrders
                            .where((o) => o['status'] == 'cancelled')
                            .length;

                        final double advanceCancellationRate = allAdvanceOrders.isNotEmpty
                            ? (cancelledAdvanceOrdersCount / allAdvanceOrders.length) * 100
                            : 0.0;

                        final Map<String, int> popularAdvanceItems = {};
                        for (var o in allAdvanceOrders) {
                          if (o['status'] == 'done' || o['status'] == 'completed' || o['status'] == 'ready') {
                            final items = o['selected_menu_items'] as Map<String, dynamic>? ?? {};
                            items.forEach((name, qty) {
                              popularAdvanceItems[name] = (popularAdvanceItems[name] ?? 0) + (qty as num).toInt();
                            });
                          }
                        }

                        // Calculate Event Reservation Performance Metrics
                        final paidEventReservations = allReservations.where((r) {
                          final pStatus = r['payment_status']?.toString() ?? '';
                          return pStatus == 'paid' || pStatus == 'fully_paid' || pStatus == 'deposit_paid';
                        }).toList();

                        final double eventReservationRevenueTotal = paidEventReservations.fold(0.0, (sum, r) {
                          final pStatus = r['payment_status']?.toString() ?? '';
                          if (pStatus == 'deposit_paid') {
                            return sum + ((r['deposit_amount'] as num?)?.toDouble() ?? ((r['total_price'] as num?)?.toDouble() ?? 0.0) / 2);
                          }
                          return sum + ((r['total_price'] as num?)?.toDouble() ?? 0.0);
                        });

                        final int completedEventReservationsCount = allReservations
                            .where((r) => r['status'] == 'completed' || r['status'] == 'confirmed')
                            .length;

                        final int cancelledEventReservationsCount = allReservations
                            .where((r) => r['status'] == 'cancelled')
                            .length;

                        final double eventCancellationRate = allReservations.isNotEmpty
                            ? (cancelledEventReservationsCount / allReservations.length) * 100
                            : 0.0;

                        final Map<String, int> popularEventTypes = {};
                        for (var r in allReservations) {
                          final eventType = r['event_type']?.toString() ?? 'Special Event';
                          popularEventTypes[eventType] = (popularEventTypes[eventType] ?? 0) + 1;
                        }

                        // Compile All Transactions for the Table
                        List<Map<String, dynamic>> combinedTransactions = [];

                        // 1. Regular Orders
                        for (var o in allOrders) {
                          final date = DateTime.tryParse(o['created_at'] ?? '');
                          if (date == null) continue;
                          final name = o['customer_name']?.toString() ?? 'Guest';
                          final dbStatus = o['kitchen_status']?.toString() ?? 'Done';
                          final rawAmt = (o['total_amount'] as num?)?.toDouble() ?? (o['total_price'] as num?)?.toDouble() ?? 0.0;
                          final rawTxnId = o['transaction_id'];
                          final rawDbId = o['id']?.toString() ?? '';
                          final shortRef = _formatTransactionRef(rawTxnId, rawDbId, 'Regular');
                          final processedBy = _resolveProcessedBy(o, 'Regular');
                          final paymentMethod = o['payment_method']?.toString() ?? 'Cash';
                          
                          combinedTransactions.add({
                            'db_id': rawDbId,
                            'raw_id': (rawTxnId ?? rawDbId).toString(),
                            'id': shortRef,
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(date.toLocal()),
                            'full_date': DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()),
                            'raw_date': date,
                            'raw_amount': rawAmt,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': dbStatus == 'Done' ? 'Completed' : (dbStatus.isEmpty ? 'Completed' : dbStatus),
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.regularOrderBlue,
                            'type': 'Regular',
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                          });
                        }

                        // 2. Advance Orders
                        for (var adv in allAdvanceOrders) {
                          final date = DateTime.tryParse(adv['order_date'] ?? '');
                          if (date == null) continue;
                          final name = adv['customer_name']?.toString() ?? 'Guest';
                          final status = adv['status']?.toString().toLowerCase() ?? 'pending';
                          final rawAmt = (adv['total_price'] as num?)?.toDouble() ?? 0.0;
                          final rawDbId = adv['id']?.toString() ?? '';
                          final shortRef = _formatTransactionRef(adv['transaction_id'], rawDbId, 'Advance');
                          final processedBy = _resolveProcessedBy(adv, 'Advance');
                          final paymentMethod = adv['payment_method']?.toString() ?? 'Online';

                          combinedTransactions.add({
                            'db_id': rawDbId,
                            'raw_id': (adv['transaction_id'] ?? rawDbId).toString(),
                            'id': shortRef,
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(date.toLocal()),
                            'full_date': DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()),
                            'raw_date': date,
                            'raw_amount': rawAmt,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': status[0].toUpperCase() + status.substring(1),
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.advanceOrderGreen,
                            'type': 'Advance',
                            'selected_menu_items': adv['selected_menu_items'],
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                          });
                        }

                        // 3. Reservations
                        for (var res in allReservations) {
                          final date = DateTime.tryParse(res['event_date'] ?? '');
                          if (date == null) continue;
                          final name = res['customer_name']?.toString() ?? 'Guest';
                          final status = res['status']?.toString().toLowerCase() ?? 'pending';
                          final pStatus = res['payment_status']?.toString() ?? '';
                          double rawAmt = 0.0;
                          if (pStatus == 'deposit_paid') {
                            rawAmt = (res['deposit_amount'] as num?)?.toDouble() ?? ((res['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
                          } else {
                            rawAmt = (res['total_price'] as num?)?.toDouble() ?? 0.0;
                          }
                          final rawDbId = res['id']?.toString() ?? '';
                          final shortRef = _formatTransactionRef(res['transaction_id'], rawDbId, 'Reservation');
                          final processedBy = _resolveProcessedBy(res, 'Reservation');
                          final paymentMethod = res['payment_method']?.toString() ?? (pStatus == 'deposit_paid' ? 'Deposit (GCash/Card)' : 'Full Payment');

                          combinedTransactions.add({
                            'db_id': rawDbId,
                            'raw_id': (res['transaction_id'] ?? rawDbId).toString(),
                            'id': shortRef,
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(date.toLocal()),
                            'full_date': DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()),
                            'raw_date': date,
                            'raw_amount': rawAmt,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Pending',
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.reservationPurple,
                            'type': 'Reservation',
                            'selected_menu_items': res['selected_menu_items'],
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                          });
                        }

                        // Sort newest first
                        combinedTransactions.sort((a, b) => (b['raw_date'] as DateTime).compareTo(a['raw_date'] as DateTime));

                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isDesktop ? AppTheme.xxl : AppTheme.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Header Bar
                                _buildExecutiveHeader(combinedTransactions, metrics),
                                const SizedBox(height: AppTheme.xl),

                                // Top KPI Summary Cards
                                _buildExecutiveKpiCards(metrics, isDesktop),
                                const SizedBox(height: AppTheme.xl),

                                // Main Revenue Chart Card
                                _buildInteractiveChartCard(chartValues, metrics, isDesktop),
                                const SizedBox(height: AppTheme.xl),

                                // Side-by-side: Location Forecasting & Channel Performance Deep-Dives
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _buildLocationForecastingCard(),
                                      ),
                                      const SizedBox(width: AppTheme.xl),
                                      Expanded(
                                        flex: 6,
                                        child: _buildChannelDeepDiveCard(
                                          advanceOrderRevenueTotal,
                                          completedAdvanceOrdersCount,
                                          advanceCancellationRate,
                                          popularAdvanceItems,
                                          eventReservationRevenueTotal,
                                          completedEventReservationsCount,
                                          eventCancellationRate,
                                          popularEventTypes,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _buildLocationForecastingCard(),
                                  const SizedBox(height: AppTheme.xl),
                                  _buildChannelDeepDiveCard(
                                    advanceOrderRevenueTotal,
                                    completedAdvanceOrdersCount,
                                    advanceCancellationRate,
                                    popularAdvanceItems,
                                    eventReservationRevenueTotal,
                                    completedEventReservationsCount,
                                    eventCancellationRate,
                                    popularEventTypes,
                                  ),
                                ],
                                const SizedBox(height: AppTheme.xl),

                                // Transactions & Ledger Table Section
                                _buildTransactionsLedgerSection(combinedTransactions, metrics),
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

  // ── 1. Top Executive Header ──────────────────────────────────────────────────
  Widget _buildExecutiveHeader(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitleBlock(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _periodDropdownWidget(),
                    _yearDropdownWidget(),
                    _exportButtonWidget(transactions, metrics),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeaderTitleBlock()),
                _periodDropdownWidget(),
                const SizedBox(width: 10),
                _yearDropdownWidget(),
                const SizedBox(width: 12),
                _exportButtonWidget(transactions, metrics),
              ],
            ),
    );
  }

  Widget _buildHeaderTitleBlock() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.adminSidebarBackground, AppTheme.adminActiveSidebarBackground],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.adminSidebarBackground.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.analytics_rounded, color: AppTheme.warmGold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Sales & Revenue Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.adminPrimaryText,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: AppTheme.successGreen, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE SYNC', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.successGreen)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Real-time multi-channel sales analytics and financial velocity',
                style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodDropdownWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _periodDropdownFocusNode,
          value: selectedPeriod,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
          dropdownColor: Colors.white,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
          items: ['Daily', 'Weekly', 'Monthly', 'Annually']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            _periodDropdownFocusNode.unfocus();
            if (v != null && mounted) setState(() => selectedPeriod = v);
          },
        ),
      ),
    );
  }

  Widget _yearDropdownWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 14, color: AppTheme.mediumGrey),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              focusNode: _yearDropdownFocusNode,
              value: selectedYear,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
              dropdownColor: Colors.white,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
              items: ['2023', '2024', '2025', '2026']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                _yearDropdownFocusNode.unfocus();
                if (v != null && mounted) setState(() => selectedYear = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportButtonWidget(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    return ElevatedButton.icon(
      onPressed: () => _exportToCSV(
        transactions,
        'YangChow_SalesReport_${selectedYear}_$selectedPeriod',
        metrics: metrics,
      ),
      icon: const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
      label: const Text('Export CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.adminSidebarBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        elevation: 0,
      ),
    );
  }

  // ── 2. Top Executive KPI Cards ────────────────────────────────────────────────
  Widget _buildExecutiveKpiCards(Map<String, dynamic> data, bool isDesktop) {
    final double revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
    final int orders = (data['orders'] as num?)?.toInt() ?? 0;
    final double avgOrder = (data['avgOrder'] as num?)?.toDouble() ?? 0.0;
    final int customers = (data['customers'] as num?)?.toInt() ?? 0;
    final int lowStock = (data['lowStock'] as num?)?.toInt() ?? 0;

    final cards = [
      // 1. Featured Gross Revenue Card
      _buildFeaturedRevenueCard(revenue, data),
      // 2. Total Completed Orders
      _buildStandardKpiCard(
        title: 'Total Orders',
        value: orders.toString(),
        unit: 'Orders',
        subtitle: 'All completed orders',
        icon: Icons.shopping_bag_outlined,
        accentColor: AppTheme.infoBlue,
      ),
      // 3. Average Order Value
      _buildStandardKpiCard(
        title: 'Avg. Spend Per Order',
        value: _currencyFormat.format(avgOrder),
        unit: '',
        subtitle: 'Average bill per customer',
        icon: Icons.receipt_long_outlined,
        accentColor: AppTheme.adminPrimaryAccent,
      ),
      // 4. Unique Patrons
      _buildStandardKpiCard(
        title: 'Active Customers',
        value: customers.toString(),
        unit: 'Served',
        subtitle: 'Unique customer records',
        icon: Icons.people_outline_rounded,
        accentColor: const Color(0xFF8B5CF6),
      ),
      // 5. Stock Health / Alert
      _buildStandardKpiCard(
        title: 'Inventory Alert',
        value: lowStock.toString(),
        unit: lowStock == 1 ? 'Item Low' : 'Items Low',
        subtitle: lowStock > 0 ? 'Action needed in stock' : 'Optimal inventory',
        icon: Icons.inventory_2_outlined,
        accentColor: lowStock > 0 ? AppTheme.errorRed : AppTheme.successGreen,
        trend: lowStock > 0 ? 'ALERT' : 'GOOD',
        isWarning: lowStock > 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1150) {
          return Row(
            children: cards.map((c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            )).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: cards.map((c) => Container(
              width: 230,
              margin: const EdgeInsets.only(right: 12),
              child: c,
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedRevenueCard(double revenue, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14332E), Color(0xFF1B4942), Color(0xFF163E37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.warmGold, size: 10),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'GROSS REVENUE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.warmGold, letterSpacing: 0.4),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_rounded, color: AppTheme.warmGold, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _currencyFormat.format(revenue),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Total Sales from All Channels',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFC7D6D3),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCompactCurrency(dynamic val) {
    final double numVal = (val as num?)?.toDouble() ?? 0.0;
    if (numVal >= 1000000) {
      return '₱${(numVal / 1000000).toStringAsFixed(1)}M';
    } else if (numVal >= 1000) {
      return '₱${(numVal / 1000).toStringAsFixed(1)}k';
    }
    return '₱${numVal.toStringAsFixed(0)}';
  }

  Widget _buildStandardKpiCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? trend,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.adminSecondaryText,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.adminPrimaryText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.adminSecondaryText,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (trend != null && trend.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? AppTheme.errorRed.withValues(alpha: 0.1)
                        : AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isWarning ? AppTheme.errorRed : AppTheme.successGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.adminSecondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Interactive Multi-Channel Revenue Chart ────────────────────────────────
  Widget _buildInteractiveChartCard(Map<String, List<double>> chartData, Map<String, dynamic> metrics, bool isDesktop) {
    final labels = getChartLabels();
    final int length = chartData['regular']?.length ?? 0;
    
    final List<_SalesReportData> chartList = List.generate(length, (i) {
      final label = i < labels.length ? labels[i] : 'P${i + 1}';
      final reg = i < (chartData['regular']?.length ?? 0) ? chartData['regular']![i] : 0.0;
      final adv = i < (chartData['advance']?.length ?? 0) ? chartData['advance']![i] : 0.0;
      final res = i < (chartData['reservation']?.length ?? 0) ? chartData['reservation']![i] : 0.0;
      return _SalesReportData(label, reg, adv, res);
    });

    double maxY = 1000.0;
    for (var item in chartList) {
      double total = 0.0;
      if (activeStreams.contains('Regular')) total += item.regular;
      if (activeStreams.contains('Advance')) total += item.advance;
      if (activeStreams.contains('Reservation')) total += item.reservation;
      if (total > maxY) maxY = total;
    }
    maxY = (maxY * 1.25).clamp(1000.0, 5000000.0);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Header & Controls
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue Analytics & Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.adminPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aggregated turnover for $selectedPeriod ($selectedYear)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildStreamFilterPill('Walk-in (Regular)', 'Regular', AppTheme.regularOrderBlue),
                    const SizedBox(width: 8),
                    _buildStreamFilterPill('Advance Orders', 'Advance', AppTheme.advanceOrderGreen),
                    const SizedBox(width: 8),
                    _buildStreamFilterPill('Event Catering', 'Reservation', AppTheme.reservationPurple),
                    const SizedBox(width: 16),
                    _buildChartTypeToggle(),
                  ],
                ),
              ],
            )
          else ...[
            const Text(
              'Revenue Analytics & Trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.adminPrimaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStreamFilterPill('Walk-in', 'Regular', AppTheme.regularOrderBlue),
                _buildStreamFilterPill('Advance', 'Advance', AppTheme.advanceOrderGreen),
                _buildStreamFilterPill('Events', 'Reservation', AppTheme.reservationPurple),
                _buildChartTypeToggle(),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Chart Canvas
          SizedBox(
            height: isDesktop ? 320 : 250,
            child: SfCartesianChart(
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
                      color: AppTheme.adminSidebarBackground,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.label} • ${series.name ?? 'Revenue'}',
                          style: const TextStyle(color: AppTheme.warmGold, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(val),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                },
              ),
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(color: AppTheme.adminSecondaryText, fontSize: 11, fontWeight: FontWeight.w600),
                axisLine: const AxisLine(width: 1, color: AppTheme.cardBorder),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                labelStyle: const TextStyle(color: AppTheme.adminSecondaryText, fontSize: 10, fontWeight: FontWeight.bold),
                numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
                majorGridLines: MajorGridLines(
                  color: AppTheme.cardBorder.withValues(alpha: 0.8),
                  width: 1,
                  dashArray: const [4, 4],
                ),
                maximum: maxY,
              ),
              series: selectedChartType == 'Area'
                  ? <CartesianSeries<_SalesReportData, String>>[
                      if (activeStreams.contains('Regular'))
                        SplineAreaSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.regular,
                          name: 'Walk-in Orders',
                          color: AppTheme.regularOrderBlue.withValues(alpha: 0.18),
                          borderColor: AppTheme.regularOrderBlue,
                          borderWidth: 2.5,
                          animationDuration: 800,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            width: 5,
                            height: 5,
                            color: Colors.white,
                            borderColor: AppTheme.regularOrderBlue,
                            borderWidth: 2,
                          ),
                        ),
                      if (activeStreams.contains('Advance'))
                        SplineAreaSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.advance,
                          name: 'Advance Orders',
                          color: AppTheme.advanceOrderGreen.withValues(alpha: 0.18),
                          borderColor: AppTheme.advanceOrderGreen,
                          borderWidth: 2.5,
                          animationDuration: 800,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            width: 5,
                            height: 5,
                            color: Colors.white,
                            borderColor: AppTheme.advanceOrderGreen,
                            borderWidth: 2,
                          ),
                        ),
                      if (activeStreams.contains('Reservation'))
                        SplineAreaSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.reservation,
                          name: 'Event Catering',
                          color: AppTheme.reservationPurple.withValues(alpha: 0.18),
                          borderColor: AppTheme.reservationPurple,
                          borderWidth: 2.5,
                          animationDuration: 800,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            width: 5,
                            height: 5,
                            color: Colors.white,
                            borderColor: AppTheme.reservationPurple,
                            borderWidth: 2,
                          ),
                        ),
                    ]
                  : <CartesianSeries<_SalesReportData, String>>[
                      if (activeStreams.contains('Regular'))
                        StackedColumnSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.regular,
                          name: 'Walk-in Orders',
                          color: AppTheme.regularOrderBlue,
                          width: 0.5,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          animationDuration: 800,
                        ),
                      if (activeStreams.contains('Advance'))
                        StackedColumnSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.advance,
                          name: 'Advance Orders',
                          color: AppTheme.advanceOrderGreen,
                          width: 0.5,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          animationDuration: 800,
                        ),
                      if (activeStreams.contains('Reservation'))
                        StackedColumnSeries<_SalesReportData, String>(
                          dataSource: chartList,
                          xValueMapper: (_SalesReportData d, _) => d.label,
                          yValueMapper: (_SalesReportData d, _) => d.reservation,
                          name: 'Event Catering',
                          color: AppTheme.reservationPurple,
                          width: 0.5,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          animationDuration: 800,
                        ),
                    ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),

          // Micro Insights Bar
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 16, color: AppTheme.adminPrimaryAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Insights: Channel contribution: Regular (${_calcPercentage(metrics['regularRevenue'], metrics['revenue'])}), Advance (${_calcPercentage(metrics['advanceRevenue'], metrics['revenue'])}), Events (${_calcPercentage(metrics['reservationRevenue'], metrics['revenue'])}).',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calcPercentage(dynamic part, dynamic total) {
    final p = (part as num?)?.toDouble() ?? 0.0;
    final t = (total as num?)?.toDouble() ?? 0.0;
    if (t <= 0) return '0%';
    return '${((p / t) * 100).toStringAsFixed(1)}%';
  }

  Widget _buildStreamFilterPill(String label, String streamKey, Color color) {
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
                  content: Text('At least one sales stream must be selected.'),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : AppTheme.adminMainBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : AppTheme.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : AppTheme.mediumGrey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : AppTheme.adminSecondaryText,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chartTypeOption('Area', Icons.show_chart_rounded),
          _chartTypeOption('Bar', Icons.bar_chart_rounded),
        ],
      ),
    );
  }

  Widget _chartTypeOption(String type, IconData icon) {
    final isSelected = selectedChartType == type;
    return GestureDetector(
      onTap: () => setState(() => selectedChartType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTheme.adminSidebarBackground : AppTheme.mediumGrey),
            const SizedBox(width: 4),
            Text(
              type,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.adminSidebarBackground : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Location Sales Forecasting Card ───────────────────────────────────────
  Widget _buildLocationForecastingCard() {
    final topLocations = _locationData.take(5).toList();
    final double totalRevenueSum = topLocations.fold<double>(
      0.0,
      (sum, loc) => sum + ((loc['total_revenue'] as num?)?.toDouble() ?? 0.0),
    );

    final colors = [
      AppTheme.adminSidebarBackground,
      AppTheme.warmGold,
      AppTheme.infoBlue,
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: AppTheme.adminPrimaryAccent),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Cities Sales Distribution',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildLocationPeriodDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          if (topLocations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined, color: AppTheme.mediumGrey, size: 36),
                    SizedBox(height: 8),
                    Text('No customer location data recorded for this range.', style: TextStyle(color: AppTheme.mediumGrey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 160,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries<_LocationPieData, String>>[
                  DoughnutSeries<_LocationPieData, String>(
                    dataSource: topLocations.asMap().entries.map((entry) {
                      final i = entry.key;
                      final loc = entry.value;
                      final rev = (loc['total_revenue'] as num?)?.toDouble() ?? 0.0;
                      final pct = totalRevenueSum > 0 ? (rev / totalRevenueSum) * 100 : 0.0;
                      return _LocationPieData(
                        loc['location']?.toString() ?? 'City',
                        rev,
                        '${pct.toStringAsFixed(1)}%',
                        colors[i % colors.length],
                      );
                    }).toList(),
                    xValueMapper: (_LocationPieData d, _) => d.location,
                    yValueMapper: (_LocationPieData d, _) => d.count,
                    pointColorMapper: (_LocationPieData d, _) => d.color,
                    innerRadius: '65%',
                    radius: '95%',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                    ),
                    dataLabelMapper: (_LocationPieData d, _) => d.percentage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Ranked Leaderboard
            ...topLocations.asMap().entries.map((entry) {
              final idx = entry.key;
              final loc = entry.value;
              final rev = (loc['total_revenue'] as num?)?.toDouble() ?? 0.0;
              final orderCount = loc['order_count'] ?? 0;
              final pct = totalRevenueSum > 0 ? (rev / totalRevenueSum) : 0.0;
              final color = colors[idx % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '#${idx + 1}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc['location']?.toString() ?? 'Unknown',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$orderCount orders • ${_currencyFormat.format(rev)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.adminSecondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.adminMainBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _locationPeriodFocusNode,
          value: _locationPeriod,
          dropdownColor: Colors.white,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.darkGrey),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          items: ['All Time', 'Today', 'This Week', 'This Month', 'This Year']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            _locationPeriodFocusNode.unfocus();
            if (v != null && mounted) {
              setState(() => _locationPeriod = v);
              _fetchLocationData();
            }
          },
        ),
      ),
    );
  }

  // ── 5. Channel Performance Deep-Dive Card ────────────────────────────────────
  Widget _buildChannelDeepDiveCard(
    double advanceRevenue,
    int advanceCompleted,
    double advanceCancelRate,
    Map<String, int> popularAdvanceItems,
    double eventRevenue,
    int eventCompleted,
    double eventCancelRate,
    Map<String, int> popularEventTypes,
  ) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.layers_outlined, size: 18, color: AppTheme.advanceOrderGreen),
                  SizedBox(width: 8),
                  Text(
                    'Channel Performance Velocity',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _showEventReservationPerformance = !_showEventReservationPerformance),
                icon: Icon(
                  _showEventReservationPerformance ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppTheme.adminSecondaryText,
                  size: 20,
                ),
                tooltip: 'Toggle Details',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Advance Orders Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.advanceOrderGreen.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.advanceOrderGreen.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.inventory_rounded, size: 16, color: AppTheme.advanceOrderGreen),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Advance Orders Channel',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_currencyFormat.format(advanceRevenue), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.advanceOrderGreen)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildMicroMetric('Completed', '$advanceCompleted orders', Icons.check_circle_outline, AppTheme.successGreen),
                    _buildMicroMetric('Cancellation', '${advanceCancelRate.toStringAsFixed(1)}%', Icons.cancel_outlined, advanceCancelRate > 10 ? AppTheme.errorRed : AppTheme.mediumGrey),
                  ],
                ),
                if (popularAdvanceItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Top Pre-Ordered Items:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminSecondaryText)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (popularAdvanceItems.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                        .take(4)
                        .map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Text(
                                '${e.key} (${e.value})',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Event Catering Summary
          if (_showEventReservationPerformance)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.reservationPurple.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.reservationPurple.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.celebration_rounded, size: 16, color: AppTheme.reservationPurple),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Event Catering Channel',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_currencyFormat.format(eventRevenue), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.reservationPurple)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMicroMetric('Events Hosted', '$eventCompleted confirmed', Icons.event_available, AppTheme.reservationPurple),
                      _buildMicroMetric('Cancellation', '${eventCancelRate.toStringAsFixed(1)}%', Icons.cancel_outlined, eventCancelRate > 10 ? AppTheme.errorRed : AppTheme.mediumGrey),
                    ],
                  ),
                  if (popularEventTypes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Top Event Categories:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminSecondaryText)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (popularEventTypes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                          .take(4)
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Text(
                                  '${e.key} (${e.value})',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicroMetric(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── 6. Transactions & Ledger Table Section ──────────────────────────────────
  Widget _buildTransactionsLedgerSection(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    final now = DateTime.now();

    // Filtering logic
    final filtered = transactions.where((t) {
      // 1. Channel filter
      if (_channelFilter != 'All Channels' && t['type'] != _channelFilter) {
        return false;
      }

      // 2. Status filter
      if (_statusFilter != 'All Status') {
        final st = t['status']?.toString().toLowerCase() ?? '';
        final target = _statusFilter.toLowerCase();
        if (!st.contains(target)) return false;
      }

      // 3. Time filter
      final date = t['raw_date'] as DateTime?;
      if (date != null) {
        if (_transactionPeriod == 'Daily') {
          if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
        } else if (_transactionPeriod == 'Weekly') {
          if (now.difference(date).inDays > 7) return false;
        } else if (_transactionPeriod == 'Monthly') {
          if (date.year != now.year || date.month != now.month) return false;
        } else if (_transactionPeriod == 'Yearly') {
          if (date.year != now.year) return false;
        }
      }

      // 4. Search Query
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final id = t['id']?.toString().toLowerCase() ?? '';
        final rawId = t['raw_id']?.toString().toLowerCase() ?? '';
        final dbId = t['db_id']?.toString().toLowerCase() ?? '';
        final cust = t['customer']?.toString().toLowerCase() ?? '';
        final type = t['type']?.toString().toLowerCase() ?? '';
        final processedBy = t['processed_by']?.toString().toLowerCase() ?? '';
        if (!id.contains(q) && !rawId.contains(q) && !dbId.contains(q) && !cust.contains(q) && !type.contains(q) && !processedBy.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    final totalPages = (filtered.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final paginated = filtered.skip(startIndex).take(_itemsPerPage).toList();
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Toolbar
          if (isMobile) ...[
            const Text(
              'Sales Transaction Ledger',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
            ),
            const SizedBox(height: 12),
            _buildSearchInput(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChannelFilterDropdown(),
                _buildStatusFilterDropdown(),
                _buildTransactionPeriodDropdown(),
              ],
            ),
          ] else
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Transaction Ledger',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                      ),
                      SizedBox(height: 2),
                      Text('Complete audit trail of processed food orders and events', style: TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText)),
                    ],
                  ),
                ),
                Expanded(flex: 3, child: _buildSearchInput()),
                const SizedBox(width: 8),
                _buildChannelFilterDropdown(),
                const SizedBox(width: 8),
                _buildStatusFilterDropdown(),
                const SizedBox(width: 8),
                _buildTransactionPeriodDropdown(),
              ],
            ),
          const SizedBox(height: 20),

          // Table / Cards View
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: AppTheme.mediumGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No transactions match the selected filters or search keyword.', style: TextStyle(color: AppTheme.adminSecondaryText, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (isMobile)
            ...paginated.map((t) => _buildMobileTransactionCard(t))
          else
            Column(
              children: [
                _buildDesktopTableHeader(),
                const Divider(height: 1, color: AppTheme.cardBorder),
                ...paginated.map((t) => _buildDesktopTableRow(t)),
              ],
            ),

          // Pagination
          if (totalPages > 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 16),
            _buildPaginationBar(totalPages, filtered.length),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by Ref ID, Customer...',
          hintStyle: const TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.mediumGrey, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppTheme.mediumGrey),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildChannelFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _channelDropdownFocusNode,
          value: _channelFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.darkGrey),
          dropdownColor: Colors.white,
          isDense: true,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          items: ['All Channels', 'Regular', 'Advance', 'Reservation']
              .map((c) => DropdownMenuItem(value: c, child: Text(c == 'Regular' ? 'Walk-in' : c == 'Reservation' ? 'Event' : c)))
              .toList(),
          onChanged: (v) {
            _channelDropdownFocusNode.unfocus();
            if (v != null && mounted) setState(() { _channelFilter = v; _currentPage = 1; });
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _statusDropdownFocusNode,
          value: _statusFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.darkGrey),
          dropdownColor: Colors.white,
          isDense: true,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          items: ['All Status', 'Completed', 'Ready', 'Pending', 'Confirmed', 'Cancelled']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            _statusDropdownFocusNode.unfocus();
            if (v != null && mounted) setState(() { _statusFilter = v; _currentPage = 1; });
          },
        ),
      ),
    );
  }

  Widget _buildTransactionPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _transactionPeriodFocusNode,
          value: _transactionPeriod,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.darkGrey),
          dropdownColor: Colors.white,
          isDense: true,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          items: ['All Time', 'Daily', 'Weekly', 'Monthly', 'Yearly']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            _transactionPeriodFocusNode.unfocus();
            if (v != null && mounted) setState(() { _transactionPeriod = v; _currentPage = 1; });
          },
        ),
      ),
    );
  }

  Widget _buildDesktopTableHeader() {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText, letterSpacing: 0.5);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('TRANSACTION REF', style: style)),
          Expanded(flex: 2, child: Text('CUSTOMER', style: style)),
          Expanded(flex: 2, child: Text('PROCESSED BY', style: style)),
          Expanded(flex: 2, child: Text('CHANNEL', style: style)),
          Expanded(flex: 2, child: Text('DATE & TIME', style: style)),
          Expanded(flex: 2, child: Text('AMOUNT', style: style)),
          Expanded(flex: 1, child: Text('STATUS', style: style)),
          SizedBox(width: 80, child: Text('ACTION', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }

  Widget _buildDesktopTableRow(Map<String, dynamic> t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.adminMainBackground, width: 1)),
      ),
      child: Row(
        children: [
          // Ref ID
          Expanded(
            flex: 2,
            child: Text(
              t['id'],
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
            ),
          ),
          // Customer
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: (t['color'] as Color).withValues(alpha: 0.12),
                  child: Text(
                    t['initials'],
                    style: TextStyle(color: t['color'], fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t['customer'],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Processed By
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.adminSecondaryText.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    t['processed_by'] ?? 'Staff',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.adminSecondaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Channel
          Expanded(
            flex: 2,
            child: _typeBadge(t['type']),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              t['full_date'] ?? t['date'],
              style: const TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              t['amount'],
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: _statusBadge(t['status']),
          ),
          // Action Button
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _showReceiptModal(context, t),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.adminSidebarBackground.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 12, color: AppTheme.adminSidebarBackground),
                      SizedBox(width: 4),
                      Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminSidebarBackground)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCard(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: (t['color'] as Color).withValues(alpha: 0.12),
                      child: Text(t['initials'], style: TextStyle(color: t['color'], fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['customer'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.adminPrimaryText), overflow: TextOverflow.ellipsis),
                          Text(t['id'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(t['status']),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.adminSecondaryText),
              const SizedBox(width: 4),
              Text(
                'Processed by: ${t['processed_by'] ?? 'Staff'}',
                style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _typeBadge(t['type']),
              Text(t['amount'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['full_date'] ?? t['date'], style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText)),
              TextButton.icon(
                onPressed: () => _showReceiptModal(context, t),
                icon: const Icon(Icons.visibility_outlined, size: 13, color: AppTheme.adminSidebarBackground),
                label: const Text('View Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.adminSidebarBackground)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    Color bg;
    Color textColor;
    IconData icon;
    String label = type;

    switch (type) {
      case 'Advance':
        bg = AppTheme.advanceOrderGreen.withValues(alpha: 0.1);
        textColor = AppTheme.advanceOrderGreen;
        icon = Icons.inventory_2_outlined;
        label = 'Advance';
        break;
      case 'Reservation':
        bg = AppTheme.reservationPurple.withValues(alpha: 0.1);
        textColor = AppTheme.reservationPurple;
        icon = Icons.celebration_outlined;
        label = 'Event Catering';
        break;
      default:
        bg = AppTheme.regularOrderBlue.withValues(alpha: 0.1);
        textColor = AppTheme.regularOrderBlue;
        icon = Icons.storefront_outlined;
        label = 'Walk-in';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: textColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    String normalized = status.toLowerCase();

    if (normalized.contains('done') || normalized.contains('complete') || normalized.contains('ready') || normalized.contains('paid')) {
      bg = AppTheme.successGreen.withValues(alpha: 0.12);
      text = AppTheme.successGreen;
    } else if (normalized.contains('confirm')) {
      bg = AppTheme.reservationPurple.withValues(alpha: 0.12);
      text = AppTheme.reservationPurple;
    } else if (normalized.contains('pending') || normalized.contains('prep')) {
      bg = AppTheme.warningOrange.withValues(alpha: 0.12);
      text = AppTheme.warningOrange;
    } else if (normalized.contains('cancel')) {
      bg = AppTheme.errorRed.withValues(alpha: 0.12);
      text = AppTheme.errorRed;
    } else {
      bg = AppTheme.cardBorder;
      text = AppTheme.darkGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(color: text, fontSize: 10.5, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages, int totalItems) {
    final start = (_currentPage - 1) * _itemsPerPage + 1;
    final end = (_currentPage * _itemsPerPage).clamp(1, totalItems);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing $start-$end of $totalItems entries', style: const TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              style: IconButton.styleFrom(
                backgroundColor: _currentPage > 1 ? AppTheme.adminSidebarBackground : AppTheme.adminMainBackground,
                foregroundColor: _currentPage > 1 ? Colors.white : AppTheme.mediumGrey,
                minimumSize: const Size(32, 32),
              ),
            ),
            const SizedBox(width: 8),
            Text('Page $_currentPage of $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              style: IconButton.styleFrom(
                backgroundColor: _currentPage < totalPages ? AppTheme.adminSidebarBackground : AppTheme.adminMainBackground,
                foregroundColor: _currentPage < totalPages ? Colors.white : AppTheme.mediumGrey,
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Models ───────────────────────────────────────────────────────────────────
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