import 'dart:math';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File, Directory, Platform;
import 'dart:async';
import 'package:yang_chow/utils/file_download.dart';
import 'package:yang_chow/utils/global_messenger.dart';
import 'package:yang_chow/services/location_analytics_service.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/models/menu_item.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage>
    with TickerProviderStateMixin {
  String selectedPeriod = 'Monthly';
  String selectedYear = DateTime.now().year.toString();
  final List<String> _monthFilters = const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<String> _weekFilters = const ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];

  late String selectedDailyMonth;
  late String selectedDailyDay;
  late String selectedWeeklyMonth;
  late String selectedWeeklyWeek;
  late String selectedMonthlyMonth;

  final FocusNode _dailyMonthFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _dailyDayFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _weeklyMonthFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _weeklyWeekFocusNode = FocusNode(canRequestFocus: false);
  final FocusNode _monthlyMonthFocusNode = FocusNode(canRequestFocus: false);

  String selectedChartType = 'Area'; // 'Area', 'Bar'
  Set<String> activeStreams = {'Regular', 'Advance', 'Reservation'};
  bool _showEventReservationPerformance = true;
  String _paymentDistributionMode = 'Revenue'; // 'Revenue' or 'Count'
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
  bool _includeOthersInLocations = false;

  // Operational Intelligence & Menu Velocity state
  _ProcessedReportData? _operationalReportData;
  bool _isLoadingOperationalData = false;
  String? _operationalDataCacheKey;
  String _menuRankingFilter = 'best'; // 'best', 'slow'
  bool _showAllOperationalItems = false;

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

  Stream<List<Map<String, dynamic>>> _ordersStream() async* {
    const int pageSize = 1000;
    Future<List<Map<String, dynamic>>> fetchAll() async {
      List<Map<String, dynamic>> allRows = [];
      int from = 0;
      bool hasMore = true;
      while (hasMore) {
        final response = await _supabase
            .from('orders')
            .select()
            .order('created_at', ascending: false)
            .range(from, from + pageSize - 1);
        final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response);
        allRows.addAll(rows);
        if (rows.length < pageSize) {
          hasMore = false;
        } else {
          from += pageSize;
        }
      }
      return allRows;
    }

    try {
      yield await fetchAll();
    } catch (e) {
      debugPrint('Error in _ordersStream: $e');
    }

    await for (final _ in _supabase.from('orders').stream(primaryKey: ['id'])) {
      try {
        yield await fetchAll();
      } catch (_) {}
    }
  }

  Stream<List<Map<String, dynamic>>> _advanceOrdersStream() async* {
    const int pageSize = 1000;
    Future<List<Map<String, dynamic>>> fetchAll() async {
      List<Map<String, dynamic>> allRows = [];
      int from = 0;
      bool hasMore = true;
      while (hasMore) {
        final response = await _supabase
            .from('advance_orders')
            .select()
            .order('created_at', ascending: false)
            .range(from, from + pageSize - 1);
        final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response);
        allRows.addAll(rows);
        if (rows.length < pageSize) {
          hasMore = false;
        } else {
          from += pageSize;
        }
      }
      return allRows;
    }

    try {
      yield await fetchAll();
    } catch (e) {
      debugPrint('Error in _advanceOrdersStream: $e');
    }

    await for (final _ in _supabase.from('advance_orders').stream(primaryKey: ['id'])) {
      try {
        yield await fetchAll();
      } catch (_) {}
    }
  }

  Stream<List<Map<String, dynamic>>> _reservationsStream() async* {
    const int pageSize = 1000;
    Future<List<Map<String, dynamic>>> fetchAll() async {
      List<Map<String, dynamic>> allRows = [];
      int from = 0;
      bool hasMore = true;
      while (hasMore) {
        final response = await _supabase
            .from('reservations')
            .select()
            .order('created_at', ascending: false)
            .range(from, from + pageSize - 1);
        final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response);
        allRows.addAll(rows);
        if (rows.length < pageSize) {
          hasMore = false;
        } else {
          from += pageSize;
        }
      }
      return allRows;
    }

    try {
      yield await fetchAll();
    } catch (e) {
      debugPrint('Error in _reservationsStream: $e');
    }

    await for (final _ in _supabase.from('reservations').stream(primaryKey: ['id'])) {
      try {
        yield await fetchAll();
      } catch (_) {}
    }
  }

  Stream<List<Map<String, dynamic>>> _inventoryStream() {
    return _supabase
        .from('inventory')
        .stream(primaryKey: ['id']);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDailyMonth = _monthFilters[now.month - 1];
    selectedDailyDay = now.day.toString();
    selectedWeeklyMonth = _monthFilters[now.month - 1];
    final currentWeekNum = ((now.day - 1) ~/ 7) + 1;
    selectedWeeklyWeek = 'Week ${currentWeekNum.clamp(1, 5)}';
    selectedMonthlyMonth = _monthFilters[now.month - 1];

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
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchLocationData();
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
        limit: 25,
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
    _dailyMonthFocusNode.dispose();
    _dailyDayFocusNode.dispose();
    _weeklyMonthFocusNode.dispose();
    _weeklyWeekFocusNode.dispose();
    _monthlyMonthFocusNode.dispose();
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
      return item['staff_email'].toString().trim();
    }
    // Fallback: use the currently logged-in user's email
    return Supabase.instance.client.auth.currentUser?.email ?? 'POS Staff';
  }

  int _getMonthIndex(String monthName) {
    switch (monthName) {
      case 'January': return 1;
      case 'February': return 2;
      case 'March': return 3;
      case 'April': return 4;
      case 'May': return 5;
      case 'June': return 6;
      case 'July': return 7;
      case 'August': return 8;
      case 'September': return 9;
      case 'October': return 10;
      case 'November': return 11;
      case 'December': return 12;
      default: return 1;
    }
  }

  bool _isInSelectedWeekOfMonth(DateTime date, int weekNumber, int monthIndex, int year) {
    if (date.year != year || date.month != monthIndex) return false;
    final int startDay = (weekNumber - 1) * 7 + 1;
    final int daysInMonth = DateTime(year, monthIndex + 1, 0).day;
    if (startDay > daysInMonth) return false;
    final int endDay = min(startDay + 6, daysInMonth);
    return date.day >= startDay && date.day <= endDay;
  }

  /// Returns a short date range label for a given week key (e.g. "Week 1")
  /// in the context of [selectedWeeklyMonth] and [selectedYear].
  /// Example output: "Sep 1–7"
  String _getWeekDateRangeLabel(String weekKey) {
    try {
      final year = int.tryParse(selectedYear) ?? DateTime.now().year;
      final monthIdx = _getMonthIndex(selectedWeeklyMonth);
      final weekNum = int.tryParse(weekKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final startDay = (weekNum - 1) * 7 + 1;
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      if (startDay > daysInMonth) return '';
      final endDay = min(startDay + 6, daysInMonth);
      final monthAbbr = DateFormat('MMM').format(DateTime(year, monthIdx));
      return '$monthAbbr $startDay–$endDay';
    } catch (_) {
      return '';
    }
  }

  String _getSubPeriodCacheKey() {
    if (selectedPeriod == 'Daily') return '${selectedDailyMonth}_$selectedDailyDay';
    if (selectedPeriod == 'Weekly') return '${selectedWeeklyMonth}_$selectedWeeklyWeek';
    if (selectedPeriod == 'Monthly') return selectedMonthlyMonth;
    return 'AllYears';
  }

  bool _isDateInSelectedPeriod(DateTime? rawDate) {
    if (rawDate == null) return false;
    final date = rawDate.toLocal();
    final year = int.tryParse(selectedYear) ?? DateTime.now().year;

    if (date.year != year) {
      return false;
    }

    switch (selectedPeriod) {
      case 'Daily':
        final monthIdx = _getMonthIndex(selectedDailyMonth);
        final day = int.tryParse(selectedDailyDay) ?? 1;
        return date.month == monthIdx && date.day == day;
      case 'Weekly':
        final monthIdx = _getMonthIndex(selectedWeeklyMonth);
        final weekNum = int.tryParse(selectedWeeklyWeek.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        return _isInSelectedWeekOfMonth(date, weekNum, monthIdx, year);
      case 'Monthly':
        final monthIdx = _getMonthIndex(selectedMonthlyMonth);
        return date.month == monthIdx;
      case 'Annually':
        return true; // Already matched date.year == year
      default:
        return false;
    }
  }

  bool _isOrderTakeout(Map<String, dynamic> order) {
    final note = (order['note']?.toString() ?? '').toUpperCase();
    final orderType = (order['order_type']?.toString() ?? '').toLowerCase();
    final diningOption = (order['dining_option']?.toString() ?? '').toLowerCase();

    if (note.contains('[TAKE HOME]') ||
        note.contains('[TAKE-OUT]') ||
        note.contains('[TAKEOUT]') ||
        note.contains('TAKE HOME') ||
        note.contains('TAKE-OUT') ||
        note.contains('TAKEOUT')) {
      return true;
    }
    if (orderType.contains('take') || orderType.contains('pick')) return true;
    if (diningOption.contains('take') || diningOption.contains('pick')) return true;

    final tbl = order['table_number']?.toString().trim();
    if ((tbl == null || tbl.isEmpty || tbl == 'null' || tbl.toUpperCase() == 'N/A') &&
        !note.contains('[DINE IN]') &&
        !orderType.contains('dine')) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> _processMetrics(
      List<Map<String, dynamic>> allOrders,
      List<Map<String, dynamic>> allAdvanceOrders,
      List<Map<String, dynamic>> allReservations, {
      Set<String>? channelFilter,
  }) {
    final activeChannels = channelFilter ?? {'Regular', 'Advance', 'Reservation'};
    double regularRevenue = 0;
    int regularOrdersCount = 0;
    double advanceRevenue = 0;
    int advanceOrdersCount = 0;
    int totalPeriodAdvanceOrders = 0;
    int advanceCancelledCount = 0;
    int totalGuestsServed = 0;
    Set<String> uniqueCustomers = {};

    final bool includeRegular = activeChannels.contains('Regular');
    final bool includeAdvance = activeChannels.contains('Advance');
    final bool includeReservation = activeChannels.contains('Reservation');

    for (var order in allOrders) {
      if (!includeRegular) break;
      final rawDate = DateTime.tryParse(order['created_at'] ?? '');
      if (_isDateInSelectedPeriod(rawDate)) {
        final status = (order['status']?.toString() ?? order['kitchen_status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (order['payment_status']?.toString() ?? '').toLowerCase();
        final isTakeout = _isOrderTakeout(order);

        // Skip cancelled or refunded walk-in / POS orders
        if (status == 'cancelled' || status == 'voided' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') {
          continue;
        }

        final amount = (order['total_amount'] as num?)?.toDouble() ?? 
                       (order['total_price'] as num?)?.toDouble() ?? 0.0;
        final name = order['customer_name']?.toString() ?? '';
        final int rawGuests = (order['number_of_guests'] as num?)?.toInt() ?? 1;
        final int orderGuests = isTakeout ? 1 : (rawGuests > 0 ? rawGuests : 1);

        regularRevenue += amount;
        regularOrdersCount++;
        totalGuestsServed += orderGuests;
        if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
      }
    }

    for (var adv in allAdvanceOrders) {
      if (!includeAdvance) break;
      final rawDate = _parseDateWithTime(adv['order_date'], adv['order_time'], adv['created_at']);
      if (_isDateInSelectedPeriod(rawDate)) {
        totalPeriodAdvanceOrders++;
        final status = (adv['status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (adv['payment_status']?.toString() ?? '').toLowerCase();
        // Skip cancelled or refunded advance orders
        if (status == 'cancelled' || status == 'voided' || status == 'refunded' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') {
          advanceCancelledCount++;
          continue;
        }

        final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';
        if (isPaid || status == 'completed' || status == 'done' || status == 'ready') {
          advanceRevenue += (adv['total_price'] as num?)?.toDouble() ?? 0.0;
          advanceOrdersCount++;
          final int rawAdvGuests = (adv['number_of_guests'] as num?)?.toInt() ?? (adv['guest_count'] as num?)?.toInt() ?? 1;
          totalGuestsServed += (rawAdvGuests > 0 ? rawAdvGuests : 1);
          final name = adv['customer_name']?.toString() ?? '';
          if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
        }
      }
    }

    int totalPeriodReservations = 0;
    int reservationCancelledCount = 0;
    double reservationRevenue = 0;
    int reservationOrdersCount = 0;
    for (var res in allReservations) {
      if (!includeReservation) break;
      final rawDate = _parseDateWithTime(res['event_date'], res['start_time'], res['created_at']);
      if (_isDateInSelectedPeriod(rawDate)) {
        totalPeriodReservations++;
        final status = (res['status']?.toString() ?? '').toLowerCase();
        final paymentStatus = (res['payment_status']?.toString() ?? '').toLowerCase();
        // Skip cancelled or refunded event reservations
        if (status == 'cancelled' || status == 'voided' || status == 'refunded' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') {
          reservationCancelledCount++;
          continue;
        }

        final int resGuests = (res['number_of_guests'] as num?)?.toInt() ?? (res['guest_count'] as num?)?.toInt() ?? (res['pax'] as num?)?.toInt() ?? 0;
        if (paymentStatus == 'deposit_paid') {
          final amt = (res['deposit_amount'] as num?)?.toDouble() ?? 
                     ((res['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
          reservationRevenue += amt;
          reservationOrdersCount++;
          totalGuestsServed += (resGuests > 0 ? resGuests : 0);
        } else if (paymentStatus == 'paid' || paymentStatus == 'fully_paid' || status == 'confirmed' || status == 'completed') {
          final amt = (res['total_price'] as num?)?.toDouble() ?? 0.0;
          reservationRevenue += amt;
          reservationOrdersCount++;
          totalGuestsServed += (resGuests > 0 ? resGuests : 0);
        }
        final name = res['customer_name']?.toString() ?? '';
        if (name.isNotEmpty && name != 'Guest') uniqueCustomers.add(name);
      }
    }

    final totalRevenue = regularRevenue + advanceRevenue + reservationRevenue;
    final totalOrders = regularOrdersCount + advanceOrdersCount + reservationOrdersCount;
    final avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;
    final double advanceCancellationRate = totalPeriodAdvanceOrders > 0
        ? (advanceCancelledCount / totalPeriodAdvanceOrders) * 100
        : 0.0;
    final double eventCancellationRate = totalPeriodReservations > 0
        ? (reservationCancelledCount / totalPeriodReservations) * 100
        : 0.0;

    return {
      'revenue': totalRevenue,
      'regularRevenue': regularRevenue,
      'advanceRevenue': advanceRevenue,
      'reservationRevenue': reservationRevenue,
      'orders': totalOrders,
      'regularOrders': regularOrdersCount,
      'advanceOrders': advanceOrdersCount,
      'reservationOrders': reservationOrdersCount,
      'customers': totalGuestsServed,
      'totalGuests': totalGuestsServed,
      'uniqueCustomers': uniqueCustomers.length,
      'avgOrder': avgOrder,
      'advanceCancellationRate': advanceCancellationRate,
      'eventCancellationRate': eventCancellationRate,
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
    final year = int.tryParse(selectedYear) ?? now.year;

    Map<int, double> regularData = {};
    Map<int, double> advanceData = {};
    Map<int, double> reservationData = {};

    void addPoint(DateTime? date, double amount, Map<int, double> target) {
      if (date == null) return;

      switch (selectedPeriod) {
        case 'Daily':
          final monthIdx = _getMonthIndex(selectedDailyMonth);
          final day = int.tryParse(selectedDailyDay) ?? 1;
          if (date.year == year && date.month == monthIdx && date.day == day) {
            // Dynamic business hours from AppSettingsService (e.g. 10 AM to 8 PM)
            final startH = AppSettingsService().getOperatingHoursStart();
            final endH = AppSettingsService().getOperatingHoursEnd();
            final clampedHour = date.hour.clamp(startH, endH);
            final hourIndex = clampedHour - startH;
            target[hourIndex] = (target[hourIndex] ?? 0) + amount;
          }
          break;
        case 'Weekly':
          final monthIdx = _getMonthIndex(selectedWeeklyMonth);
          final weekNum = int.tryParse(selectedWeeklyWeek.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          final startDay = (weekNum - 1) * 7 + 1;
          final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
          final endDay = min(startDay + 6, daysInMonth);
          if (date.year == year && date.month == monthIdx && date.day >= startDay && date.day <= endDay) {
            final key = date.day - startDay;
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
        case 'Monthly':
          final monthIdx = _getMonthIndex(selectedMonthlyMonth);
          if (date.year == year && date.month == monthIdx) {
            final key = date.day - 1;
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
        case 'Annually':
          if (date.year == year) {
            final key = date.month - 1;
            target[key] = (target[key] ?? 0) + amount;
          }
          break;
      }
    }

    // 1. Regular POS Orders (Dine-in vs Take-out)
    for (var o in orders) {
      final status = (o['status']?.toString() ?? o['kitchen_status']?.toString() ?? '').toLowerCase();
      final paymentStatus = (o['payment_status']?.toString() ?? '').toLowerCase();
      if (status == 'cancelled' || status == 'voided' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') {
        continue;
      }
      final date = DateTime.tryParse(o['created_at'] ?? '')?.toLocal();
      final amt = (o['total_amount'] as num?)?.toDouble() ?? 
                  (o['total_price'] as num?)?.toDouble() ?? 0.0;
      addPoint(date, amt, regularData);
    }

    // 2. Advance Orders
    for (var adv in advanceOrders) {
      final status = (adv['status']?.toString() ?? '').toLowerCase();
      final paymentStatus = (adv['payment_status']?.toString() ?? '').toLowerCase();
      if (status == 'cancelled' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') {
        continue;
      }
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
      if (status == 'cancelled' || pStatus == 'refunded' || pStatus == 'cancelled') {
        continue;
      }
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
      final startH = AppSettingsService().getOperatingHoursStart();
      final endH = AppSettingsService().getOperatingHoursEnd();
      length = endH - startH + 1;
    } else if (selectedPeriod == 'Weekly') {
      final monthIdx = _getMonthIndex(selectedWeeklyMonth);
      final weekNum = int.tryParse(selectedWeeklyWeek.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final startDay = (weekNum - 1) * 7 + 1;
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      final endDay = min(startDay + 6, daysInMonth);
      length = (endDay - startDay + 1).clamp(1, 7);
    } else if (selectedPeriod == 'Monthly') {
      final monthIdx = _getMonthIndex(selectedMonthlyMonth);
      length = DateTime(year, monthIdx + 1, 0).day;
    } else {
      length = 12;
    }

    return {
      'regular': List.generate(length, (i) => regularData[i] ?? 0.0),
      'advance': List.generate(length, (i) => advanceData[i] ?? 0.0),
      'reservation': List.generate(length, (i) => reservationData[i] ?? 0.0),
    };
  }

  List<String> getChartLabels() {
    final now = DateTime.now();
    final year = int.tryParse(selectedYear) ?? now.year;

    if (selectedPeriod == 'Daily') {
      final startHour = AppSettingsService().getOperatingHoursStart();
      final endHour = AppSettingsService().getOperatingHoursEnd();
      return List.generate(
        endHour - startHour + 1,
        (i) {
          final h = startHour + i;
          final period = h >= 12 ? 'PM' : 'AM';
          final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
          return '$displayH $period';
        },
      );
    } else if (selectedPeriod == 'Weekly') {
      final monthIdx = _getMonthIndex(selectedWeeklyMonth);
      final weekNum = int.tryParse(selectedWeeklyWeek.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final startDay = (weekNum - 1) * 7 + 1;
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      final endDay = min(startDay + 6, daysInMonth);
      final int numDays = (endDay - startDay + 1).clamp(1, 7);
      return List.generate(numDays, (i) {
        final d = DateTime(year, monthIdx, startDay + i);
        return DateFormat('E d').format(d);
      });
    } else if (selectedPeriod == 'Monthly') {
      final monthIdx = _getMonthIndex(selectedMonthlyMonth);
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      return List.generate(daysInMonth, (i) => '${i + 1}');
    } else {
      return const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    }
  }

  String _resolveCurrentUserEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString() ?? user?.userMetadata?['name']?.toString();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    return user?.email ?? 'POS Staff / Admin';
  }

  Future<_ProcessedReportData?> _prepareReportData(
    List<Map<String, dynamic>> transactions,
    Map<String, dynamic>? metrics, {
    Set<String>? channelFilter,
    ValueNotifier<String>? statusNotifier,
    bool silent = false,
  }) async {
    final effectiveChannels = channelFilter ?? activeStreams;
    final channelFiltered = transactions.where((t) => effectiveChannels.contains(t['type'] as String? ?? '')).toList();

    if (channelFiltered.isEmpty) {
      if (!silent) GlobalMessenger.showWarning('Walang transaksyon na naitala para sa piniling stream/channel.');
      return null;
    }

    final periodTransactions = channelFiltered.where((t) {
      final date = t['raw_date'] as DateTime?;
      return _isDateInSelectedPeriod(date);
    }).toList();

    if (periodTransactions.isEmpty) {
      if (!silent) GlobalMessenger.showWarning('Walang transaksyon para sa $selectedPeriod ($selectedYear).');
      return null;
    }

    // 1. Fetch item-level records for Regular & POS Take-out orders in this period
    final regularOrderIds = periodTransactions
        .where((t) => t['type'] == 'Regular' || t['db_source'] == 'orders' || t['is_pos_takeout'] == true)
        .map((t) => t['db_id'])
        .where((id) => id != null && id.toString().isNotEmpty)
        .toSet()
        .toList();

    final Map<String, List<Map<String, dynamic>>> orderItemsMap = {};
    if (regularOrderIds.isNotEmpty) {
      const int chunkSize = 100;
      for (int i = 0; i < regularOrderIds.length; i += chunkSize) {
        statusNotifier?.value = 'Fetching item details (${i + 1}/${regularOrderIds.length})...';
        await Future.delayed(Duration.zero);
        final chunk = regularOrderIds.sublist(
          i,
          (i + chunkSize) > regularOrderIds.length ? regularOrderIds.length : (i + chunkSize),
        );
        List<dynamic> itemsResponse;
        try {
          itemsResponse = await _supabase
              .from('order_items')
              .select('order_id, item_name, quantity, unit_price')
              .inFilter('order_id', chunk);
        } catch (err) {
          debugPrint('Error fetching order items: $err');
          itemsResponse = [];
        }

        for (var item in List<Map<String, dynamic>>.from(itemsResponse)) {
          final orderId = item['order_id']?.toString() ?? '';
          if (orderId.isNotEmpty) {
            orderItemsMap.putIfAbsent(orderId, () => []).add(item);
          }
        }
      }
    }

    // 2. Load Menu Catalog for accurate category classification & fallback pricing
    final Map<String, MenuItem> menuLookup = {};
    try {
      final catalog = await MenuService.fetchMenu();
      for (var categoryList in catalog.values) {
        for (var mi in categoryList) {
          final cleanKey = mi.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          menuLookup[cleanKey] = mi;
          menuLookup[mi.name.trim().toLowerCase()] = mi;
        }
      }
    } catch (e) {
      debugPrint('Error caching menu catalog: $e');
    }

    String resolveCategory(String rawName) {
      final cleanName = rawName.trim().toLowerCase();
      final normalized = cleanName.replaceAll(RegExp(r'\s+'), ' ');
      if (menuLookup.containsKey(cleanName)) return menuLookup[cleanName]!.category;
      if (menuLookup.containsKey(normalized)) return menuLookup[normalized]!.category;
      for (var entry in menuLookup.entries) {
        if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
          return entry.value.category;
        }
      }
      return 'Others';
    }

    // 3. Aggregate item sales, daily sales, and hourly pattern data
    final Map<String, _ReportItemSalesRecord> itemStats = {};
    final Map<String, _ReportDailySalesRecord> dailyStats = {};
    final Map<String, _ReportHourlyBucketRecord> hourlyStats = {
      '10:00 AM - 12:00 PM': _ReportHourlyBucketRecord(timeWindow: '10:00 AM - 12:00 PM', servicePeriod: 'Morning Opening (Pre-Lunch)'),
      '12:00 PM - 02:00 PM': _ReportHourlyBucketRecord(timeWindow: '12:00 PM - 02:00 PM', servicePeriod: 'Lunch Rush (Peak Hours)'),
      '02:00 PM - 05:00 PM': _ReportHourlyBucketRecord(timeWindow: '02:00 PM - 05:00 PM', servicePeriod: 'Afternoon Merienda (Off-Peak)'),
      '05:00 PM - 08:00 PM': _ReportHourlyBucketRecord(timeWindow: '05:00 PM - 08:00 PM', servicePeriod: 'Dinner Rush & Closing (Peak Hours)'),
      'Pre-Scheduled / Catering': _ReportHourlyBucketRecord(timeWindow: 'Pre-Scheduled / Catering', servicePeriod: 'Special Event & Catering Bookings'),
    };

    int totalQuantitySold = 0;

    for (int idx = 0; idx < periodTransactions.length; idx++) {
      if (idx > 0 && idx % 100 == 0) {
        statusNotifier?.value = 'Auditing transactions ($idx/${periodTransactions.length})...';
        await Future.delayed(Duration.zero);
      }
      final t = periodTransactions[idx];
      final isValidRevenue = (t['is_valid_revenue'] as bool?) ?? false;
      final recognizedAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
      final rawDate = (t['raw_date'] as DateTime).toLocal();

      String itemsSummary = 'No items';
      int itemsCount = 0;

      if (t['type'] == 'Regular' || t['db_source'] == 'orders' || t['is_pos_takeout'] == true) {
        final items = orderItemsMap[t['db_id']];
        if (items != null && items.isNotEmpty) {
          itemsSummary = items.map((i) => '${i['item_name']} x${i['quantity']}').join('; ');
          itemsCount = items.fold(0, (sum, i) => sum + ((i['quantity'] as num?)?.toInt() ?? 1));

          if (isValidRevenue) {
            totalQuantitySold += itemsCount;
            for (var it in items) {
              final itemName = it['item_name']?.toString().trim() ?? 'Menu Item';
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              final unitPrice = (it['unit_price'] as num?)?.toDouble() ?? (it['price'] as num?)?.toDouble() ?? menuLookup[itemName.toLowerCase()]?.price ?? 0.0;
              final subtotal = (it['subtotal'] as num?)?.toDouble() ?? (unitPrice * qty);
              final category = resolveCategory(itemName);

              if (itemStats.containsKey(itemName)) {
                itemStats[itemName]!.quantity += qty;
                itemStats[itemName]!.revenue += subtotal;
              } else {
                itemStats[itemName] = _ReportItemSalesRecord(name: itemName, category: category, quantity: qty, revenue: subtotal);
              }
            }
          }
        } else {
          itemsSummary = t['is_pos_takeout'] == true ? 'Standard Take-out Order' : 'Standard Walk-in Order';
          itemsCount = 1;
          if (isValidRevenue) totalQuantitySold += 1;
        }
      } else if (t['type'] == 'Advance' || t['type'] == 'Reservation') {
        if (t['selected_menu_items'] != null && t['selected_menu_items'] is Map) {
          final items = Map<String, dynamic>.from(t['selected_menu_items'] as Map);
          itemsSummary = items.entries.map((e) => '${e.key} x${e.value}').join('; ');
          itemsCount = items.values.fold(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 1));

          if (isValidRevenue) {
            totalQuantitySold += itemsCount;
            for (var entry in items.entries) {
              final itemName = entry.key.trim();
              final qty = (entry.value as num).toInt();
              final unitPrice = menuLookup[itemName.toLowerCase()]?.price ?? 0.0;
              final subtotal = unitPrice > 0 ? (unitPrice * qty) : (itemsCount > 0 ? (recognizedAmt / itemsCount) * qty : recognizedAmt);
              final category = resolveCategory(itemName);

              if (itemStats.containsKey(itemName)) {
                itemStats[itemName]!.quantity += qty;
                itemStats[itemName]!.revenue += subtotal;
              } else {
                itemStats[itemName] = _ReportItemSalesRecord(name: itemName, category: category, quantity: qty, revenue: subtotal);
              }
            }
          }
        } else {
          itemsSummary = t['type'] == 'Advance' ? 'Pre-Order Package' : 'Event Catering Package';
          itemsCount = 1;
          if (isValidRevenue) totalQuantitySold += 1;
        }
      }

      t['_itemsSummary'] = itemsSummary;
      t['_itemsCount'] = itemsCount;

      if (isValidRevenue) {
        final dateKey = DateFormat('yyyy-MM-dd').format(rawDate);
        final dayOfWeek = DateFormat('EEEE').format(rawDate);
        final dailyRecord = dailyStats.putIfAbsent(
          dateKey,
          () => _ReportDailySalesRecord(dateStr: dateKey, dayOfWeek: dayOfWeek, date: rawDate),
        );
        dailyRecord.ordersCount += 1;
        dailyRecord.itemsSold += itemsCount;
        dailyRecord.grossSales += recognizedAmt;

        final hour = rawDate.hour;
        String bucketKey;
        if (t['type'] == 'Reservation' && rawDate.hour == 0) {
          bucketKey = 'Pre-Scheduled / Catering';
        } else if (hour >= 10 && hour < 12) {
          bucketKey = '10:00 AM - 12:00 PM';
        } else if (hour >= 12 && hour < 14) {
          bucketKey = '12:00 PM - 02:00 PM';
        } else if (hour >= 14 && hour < 17) {
          bucketKey = '02:00 PM - 05:00 PM';
        } else if (hour >= 17 && hour < 20) {
          bucketKey = '05:00 PM - 08:00 PM';
        } else {
          // Outside operating hours (before 10AM or after 8PM) → catering bucket
          bucketKey = 'Pre-Scheduled / Catering';
        }
        final bucket = hourlyStats[bucketKey]!;
        bucket.ordersCount += 1;
        bucket.itemsSold += itemsCount;
        bucket.grossSales += recognizedAmt;
      }
    }

    for (var mi in menuLookup.values) {
      if (!itemStats.containsKey(mi.name)) {
        itemStats[mi.name] = _ReportItemSalesRecord(
          name: mi.name,
          category: mi.category,
          quantity: 0,
          revenue: 0.0,
        );
      }
    }

    final sortedDaily = dailyStats.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    final sortedHourly = hourlyStats.values.toList();

    final bestSellers = itemStats.values
        .where((item) => item.quantity > 0)
        .toList()
      ..sort((a, b) => b.quantity != a.quantity ? b.quantity.compareTo(a.quantity) : b.revenue.compareTo(a.revenue));

    final lowSellers = itemStats.values.toList()
      ..sort((a, b) => a.quantity != b.quantity ? a.quantity.compareTo(b.quantity) : a.revenue.compareTo(b.revenue));

    // Date range label
    String dateRangeStr = '';
    final now = DateTime.now();
    final year = int.tryParse(selectedYear) ?? now.year;

    if (selectedPeriod == 'Daily') {
      final mIdx = _getMonthIndex(selectedDailyMonth);
      final d = int.tryParse(selectedDailyDay) ?? 1;
      final targetDate = DateTime(year, mIdx, d);
      dateRangeStr = DateFormat('MMMM d, yyyy (EEEE)').format(targetDate);
    } else if (selectedPeriod == 'Weekly') {
      final mIdx = _getMonthIndex(selectedWeeklyMonth);
      final weekNum = int.tryParse(selectedWeeklyWeek.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final startDay = (weekNum - 1) * 7 + 1;
      final daysInMonth = DateTime(year, mIdx + 1, 0).day;
      final endDay = min(startDay + 6, daysInMonth);
      final startDate = DateTime(year, mIdx, startDay);
      final endDate = DateTime(year, mIdx, endDay);
      dateRangeStr = '${DateFormat('MMMM d, yyyy').format(startDate)} - ${DateFormat('MMMM d, yyyy').format(endDate)}';
    } else if (selectedPeriod == 'Monthly') {
      final mIdx = _getMonthIndex(selectedMonthlyMonth);
      final daysInMonth = DateTime(year, mIdx + 1, 0).day;
      final startDate = DateTime(year, mIdx, 1);
      final endDate = DateTime(year, mIdx, daysInMonth);
      dateRangeStr = '${DateFormat('MMMM d, yyyy').format(startDate)} - ${DateFormat('MMMM d, yyyy').format(endDate)}';
    } else {
      dateRangeStr = 'January 1, $year - December 31, $year';
    }

    String reportPeriodLabel = '';
    if (selectedPeriod == 'Daily') {
      final mIdx = _getMonthIndex(selectedDailyMonth);
      final d = int.tryParse(selectedDailyDay) ?? 1;
      reportPeriodLabel = 'Daily Operations Audit - ${DateFormat('MMM d, yyyy').format(DateTime(year, mIdx, d))}';
    } else if (selectedPeriod == 'Weekly') {
      reportPeriodLabel = 'Weekly Sales Summary ($selectedWeeklyWeek, $selectedWeeklyMonth $selectedYear)';
    } else if (selectedPeriod == 'Monthly') {
      reportPeriodLabel = 'Monthly Sales Audit ($selectedMonthlyMonth $selectedYear)';
    } else {
      reportPeriodLabel = 'Annual Sales Audit ($selectedYear)';
    }

    // Sort transactions chronologically
    periodTransactions.sort((a, b) => (a['raw_date'] as DateTime).compareTo(b['raw_date'] as DateTime));

    final double computedDailyRevenue = sortedDaily.fold<double>(0.0, (s, d) => s + d.grossSales);
    final int computedDailyOrders = sortedDaily.fold<int>(0, (s, d) => s + d.ordersCount);

    final double grossRevenue = (metrics?['revenue'] as num?)?.toDouble() ?? computedDailyRevenue;
    final double walkInRevenue = (metrics?['regularRevenue'] as num?)?.toDouble() ?? 0.0;
    final double advanceRevenue = (metrics?['advanceRevenue'] as num?)?.toDouble() ?? 0.0;
    final double reservationRevenue = (metrics?['reservationRevenue'] as num?)?.toDouble() ?? 0.0;
    final int totalOrders = (metrics?['orders'] as num?)?.toInt() ?? computedDailyOrders;
    final int walkInOrders = (metrics?['regularOrders'] as num?)?.toInt() ?? 0;
    final int advanceOrders = (metrics?['advanceOrders'] as num?)?.toInt() ?? 0;
    final int reservationOrders = (metrics?['reservationOrders'] as num?)?.toInt() ?? 0;
    final double avgOrderValue = (metrics?['avgOrder'] as num?)?.toDouble() ?? (totalOrders > 0 ? grossRevenue / totalOrders : 0.0);
    final int uniqueCustomers = (metrics?['customers'] as num?)?.toInt() ?? 0;
    final int lowStockItems = (metrics?['lowStock'] as num?)?.toInt() ?? 0;
    final double advCancelRate = (metrics?['advanceCancellationRate'] as num?)?.toDouble() ?? 0.0;
    final double eventCancelRate = (metrics?['eventCancellationRate'] as num?)?.toDouble() ?? 0.0;

    return _ProcessedReportData(
      transactions: periodTransactions,
      metrics: metrics ?? {},
      activeChannels: Set<String>.from(effectiveChannels),
      dailyList: sortedDaily,
      hourlyList: sortedHourly,
      bestSellers: bestSellers,
      lowSellers: lowSellers,
      totalQuantitySold: totalQuantitySold,
      grossRevenue: grossRevenue,
      walkInRevenue: walkInRevenue,
      advanceRevenue: advanceRevenue,
      reservationRevenue: reservationRevenue,
      totalOrders: totalOrders,
      walkInOrders: walkInOrders,
      advanceOrders: advanceOrders,
      reservationOrders: reservationOrders,
      avgOrderValue: avgOrderValue,
      uniqueCustomers: uniqueCustomers,
      lowStockItems: lowStockItems,
      advCancelRate: advCancelRate,
      eventCancelRate: eventCancelRate,
      dateRangeStr: dateRangeStr,
      reportPeriodLabel: reportPeriodLabel,
      generatedBy: _resolveCurrentUserEmail(),
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _loadOperationalData(
    List<Map<String, dynamic>> transactions,
    Map<String, dynamic> metrics,
    String cacheKey,
  ) async {
    if (_isLoadingOperationalData) return;
    _operationalDataCacheKey = cacheKey;
    setState(() => _isLoadingOperationalData = true);

    try {
      final data = await _prepareReportData(
        transactions,
        metrics,
        silent: true,
      );
      if (mounted) {
        setState(() {
          _operationalReportData = data;
          _isLoadingOperationalData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading operational report data: $e');
      if (mounted) {
        setState(() => _isLoadingOperationalData = false);
      }
    }
  }

  List<_ReportHourlyBucketRecord> _computeQuickHourlyStats(
    List<Map<String, dynamic>> transactions,
  ) {
    final Map<String, _ReportHourlyBucketRecord> hourlyStats = {
      '10:00 AM - 12:00 PM': _ReportHourlyBucketRecord(
        timeWindow: '10:00 AM - 12:00 PM',
        servicePeriod: 'Morning Opening (Pre-Lunch)',
      ),
      '12:00 PM - 02:00 PM': _ReportHourlyBucketRecord(
        timeWindow: '12:00 PM - 02:00 PM',
        servicePeriod: 'Lunch Rush (Peak Hours)',
      ),
      '02:00 PM - 05:00 PM': _ReportHourlyBucketRecord(
        timeWindow: '02:00 PM - 05:00 PM',
        servicePeriod: 'Afternoon Merienda (Off-Peak)',
      ),
      '05:00 PM - 08:00 PM': _ReportHourlyBucketRecord(
        timeWindow: '05:00 PM - 08:00 PM',
        servicePeriod: 'Dinner Rush & Closing (Peak Hours)',
      ),
      'Pre-Scheduled / Catering': _ReportHourlyBucketRecord(
        timeWindow: 'Pre-Scheduled / Catering',
        servicePeriod: 'Special Event & Catering Bookings',
      ),
    };

    final periodTransactions = transactions.where((t) {
      final date = t['raw_date'] as DateTime?;
      return _isDateInSelectedPeriod(date);
    }).toList();

    for (var t in periodTransactions) {
      final bool isValidRevenue = t['is_valid_revenue'] == true;
      if (!isValidRevenue) continue;

      final rawDate = t['raw_date'] as DateTime;
      final recognizedAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
      
      int itemsCount = 1;
      if (t['selected_menu_items'] is Map) {
        final m = t['selected_menu_items'] as Map;
        itemsCount = m.values.fold(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 1));
      }

      final hour = rawDate.hour;
      String bucketKey;
      if (t['type'] == 'Reservation' && rawDate.hour == 0) {
        bucketKey = 'Pre-Scheduled / Catering';
      } else if (hour >= 10 && hour < 12) {
        bucketKey = '10:00 AM - 12:00 PM';
      } else if (hour >= 12 && hour < 14) {
        bucketKey = '12:00 PM - 02:00 PM';
      } else if (hour >= 14 && hour < 17) {
        bucketKey = '02:00 PM - 05:00 PM';
      } else if (hour >= 17 && hour < 20) {
        bucketKey = '05:00 PM - 08:00 PM';
      } else {
        bucketKey = 'Pre-Scheduled / Catering';
      }

      final bucket = hourlyStats[bucketKey]!;
      bucket.ordersCount += 1;
      bucket.itemsSold += itemsCount;
      bucket.grossSales += recognizedAmt;
    }

    return hourlyStats.values.toList();
  }

  Future<void> _exportToExcel(
    List<Map<String, dynamic>> transactions,
    String fileName, {
    Map<String, dynamic>? metrics,
    Set<String>? channelFilter,
  }) async {
    final statusNotifier = ValueNotifier<String>('Preparing Excel report data...');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: statusNotifier,
        builder: (_, status, __) => Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.adminPrimaryAccent),
                  const SizedBox(height: 16),
                  Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text('Please wait, processing securely...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final data = await _prepareReportData(
        transactions,
        metrics,
        channelFilter: channelFilter,
        statusNotifier: statusNotifier,
      );
      if (data == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      statusNotifier.value = 'Generating Executive Summary sheet...';
      await Future.delayed(Duration.zero);

      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      final headerStyle = excel_pkg.CellStyle(
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
      );

      final titleStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );

      final subTitleStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#475569'),
      );

      final totalRowStyle = excel_pkg.CellStyle(
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E2E8F0'),
      );

      void appendStyledRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        final rowIndex = sheet.maxRows;
        sheet.appendRow(rowValues);
        if (style != null) {
          for (int c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
            cell.cellStyle = style;
          }
        }
      }

      // ────────────────────────────────────────────────────────────────────────
      // TAB 1: EXECUTIVE SUMMARY
      // ────────────────────────────────────────────────────────────────────────
      final summarySheet = excel['Executive Summary'];
      summarySheet.setColumnWidth(0, 32.0);
      summarySheet.setColumnWidth(1, 24.0);
      summarySheet.setColumnWidth(2, 45.0);

      String reportTitle;
      if (data.isEventOnly) {
        reportTitle = '${AppConstants.appName.toUpperCase()} - EVENT CATERING & BANQUET SALES REPORT';
      } else if (data.isAdvanceOnly) {
        reportTitle = '${AppConstants.appName.toUpperCase()} - ADVANCE ORDERS & PRE-ORDERS SALES REPORT';
      } else if (data.isRegularOnly) {
        reportTitle = '${AppConstants.appName.toUpperCase()} - WALK-IN & DINE-IN SALES REPORT';
      } else {
        reportTitle = '${AppConstants.appName.toUpperCase()} - RESTAURANT MANAGEMENT SALES REPORT';
      }

      appendStyledRow(summarySheet, [excel_pkg.TextCellValue(reportTitle)], style: titleStyle);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('CLA TOWN CENTER MALL, PAGSANJAN, LAGUNA')], style: subTitleStyle);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Report Period: ${data.reportPeriodLabel}')]);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Coverage: ${data.dateRangeStr}')]);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Generated On: ${DateFormat('MMMM d, yyyy h:mm:ss a').format(data.generatedAt)}')]);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Prepared By: ${data.generatedBy}')]);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Currency: PHP (Philippine Peso - ₱)')]);
      appendStyledRow(summarySheet, []);

      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Sales Metric'),
        excel_pkg.TextCellValue('Value'),
        excel_pkg.TextCellValue('Manager Notes / Context'),
      ], style: headerStyle);

      if (data.isEventOnly) {
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Event Catering Revenue'), excel_pkg.DoubleCellValue(data.grossRevenue), excel_pkg.TextCellValue('100% of event catering sales')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Bookings Fulfilled'), excel_pkg.IntCellValue(data.totalOrders), excel_pkg.TextCellValue('Confirmed and serviced event reservations')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Average Spend Per Booking'), excel_pkg.DoubleCellValue(data.avgOrderValue), excel_pkg.TextCellValue('Average package value per banquet')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Dishes & Buffet Units Prepared'), excel_pkg.IntCellValue(data.totalQuantitySold), excel_pkg.TextCellValue('Aggregated catering courses served')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Event Attendees / Pax Serviced'), excel_pkg.IntCellValue(data.uniqueCustomers), excel_pkg.TextCellValue('Confirmed event attendee headcount')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Catering Cancellation Rate'), excel_pkg.TextCellValue('${data.eventCancelRate.toStringAsFixed(1)}%'), excel_pkg.TextCellValue(data.eventCancelRate > 10 ? 'Attention Needed (>10%)' : 'Normal / Low Cancellation')]);
      } else if (data.isAdvanceOnly) {
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Advance Orders Revenue'), excel_pkg.DoubleCellValue(data.grossRevenue), excel_pkg.TextCellValue('100% of pre-order sales')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Pre-Orders Fulfilled'), excel_pkg.IntCellValue(data.totalOrders), excel_pkg.TextCellValue('Takeout and scheduled orders completed')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Average Spend Per Pre-Order'), excel_pkg.DoubleCellValue(data.avgOrderValue), excel_pkg.TextCellValue('Average ticket value per advance order')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Dishes / Food Items Packaged'), excel_pkg.IntCellValue(data.totalQuantitySold), excel_pkg.TextCellValue('Total units prepared for scheduled pickup')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Pre-Order Customers Serviced'), excel_pkg.IntCellValue(data.uniqueCustomers), excel_pkg.TextCellValue('Scheduled pickup customer headcount')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Advance Cancellation Rate'), excel_pkg.TextCellValue('${data.advCancelRate.toStringAsFixed(1)}%'), excel_pkg.TextCellValue(data.advCancelRate > 10 ? 'Attention Needed (>10%)' : 'Normal / Low Cancellation')]);
      } else if (data.isRegularOnly) {
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Gross Walk-in / Dine-in Sales'), excel_pkg.DoubleCellValue(data.grossRevenue), excel_pkg.TextCellValue('100% of POS counter sales')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Counter Tickets'), excel_pkg.IntCellValue(data.totalOrders), excel_pkg.TextCellValue('Completed POS walk-in receipts')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Average Ticket Value (AOV)'), excel_pkg.DoubleCellValue(data.avgOrderValue), excel_pkg.TextCellValue('Average spend per counter order')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Dishes Served at Counter'), excel_pkg.IntCellValue(data.totalQuantitySold), excel_pkg.TextCellValue('Dine-in / takeout units prepared by kitchen')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Diners / Guests Serviced'), excel_pkg.IntCellValue(data.uniqueCustomers), excel_pkg.TextCellValue('POS covers and diners serviced')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Low Stock Ingredients Alert'), excel_pkg.IntCellValue(data.lowStockItems), excel_pkg.TextCellValue('Items below stock threshold')]);
      } else {
        final walkInPct = data.grossRevenue > 0 ? (data.walkInRevenue / data.grossRevenue) * 100 : 0.0;
        final advPct = data.grossRevenue > 0 ? (data.advanceRevenue / data.grossRevenue) * 100 : 0.0;
        final eventPct = data.grossRevenue > 0 ? (data.reservationRevenue / data.grossRevenue) * 100 : 0.0;

        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Gross Total Sales'), excel_pkg.DoubleCellValue(data.grossRevenue), excel_pkg.TextCellValue('100.0% of total revenue')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Dine-in / Walk-in Sales'), excel_pkg.DoubleCellValue(data.walkInRevenue), excel_pkg.TextCellValue('${walkInPct.toStringAsFixed(1)}% sales share (${data.walkInOrders} orders)')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Advance Orders Sales'), excel_pkg.DoubleCellValue(data.advanceRevenue), excel_pkg.TextCellValue('${advPct.toStringAsFixed(1)}% sales share (${data.advanceOrders} orders)')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Event & Catering Sales'), excel_pkg.DoubleCellValue(data.reservationRevenue), excel_pkg.TextCellValue('${eventPct.toStringAsFixed(1)}% sales share (${data.reservationOrders} bookings)')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Completed Orders'), excel_pkg.IntCellValue(data.totalOrders), excel_pkg.TextCellValue('Fulfilled customer orders & event bookings')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Dishes / Items Sold'), excel_pkg.IntCellValue(data.totalQuantitySold), excel_pkg.TextCellValue('Aggregated food & beverage units served')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Average Spend per Order (AOV)'), excel_pkg.DoubleCellValue(data.avgOrderValue), excel_pkg.TextCellValue('Average ticket value per customer transaction')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Total Guests / Diners Serviced'), excel_pkg.IntCellValue(data.uniqueCustomers), excel_pkg.TextCellValue('Total covers and headcount serviced across all channels')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Low Stock Ingredients Alert'), excel_pkg.IntCellValue(data.lowStockItems), excel_pkg.TextCellValue('Kitchen items below minimum stock threshold')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Advance Order Cancellation Rate'), excel_pkg.TextCellValue('${data.advCancelRate.toStringAsFixed(1)}%'), excel_pkg.TextCellValue(data.advCancelRate > 10 ? 'Attention Needed (Above 10%)' : 'Normal / Low Cancellation')]);
        appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Catering Cancellation Rate'), excel_pkg.TextCellValue('${data.eventCancelRate.toStringAsFixed(1)}%'), excel_pkg.TextCellValue(data.eventCancelRate > 10 ? 'Attention Needed (Above 10%)' : 'Normal / Low Cancellation')]);
      }

      // ────────────────────────────────────────────────────────────────────────
      // TAB 2: DAILY SALES
      // ────────────────────────────────────────────────────────────────────────
      final dailySheet = excel['Daily Sales'];
      dailySheet.setColumnWidth(0, 16.0);
      dailySheet.setColumnWidth(1, 16.0);
      dailySheet.setColumnWidth(2, 16.0);
      dailySheet.setColumnWidth(3, 16.0);
      dailySheet.setColumnWidth(4, 20.0);
      dailySheet.setColumnWidth(5, 22.0);
      dailySheet.setColumnWidth(6, 26.0);

      appendStyledRow(dailySheet, [
        excel_pkg.TextCellValue('Date'),
        excel_pkg.TextCellValue('Day of Week'),
        excel_pkg.TextCellValue('Orders Handled'),
        excel_pkg.TextCellValue('Dishes Sold'),
        excel_pkg.TextCellValue('Total Sales (PHP)'),
        excel_pkg.TextCellValue('Average Spend (PHP)'),
        excel_pkg.TextCellValue('Sales Performance'),
      ], style: headerStyle);

      final double avgDailySales = data.dailyList.isNotEmpty
          ? data.dailyList.fold(0.0, (sum, d) => sum + d.grossSales) / data.dailyList.length
          : 0.0;

      for (var day in data.dailyList) {
        final dayAov = day.ordersCount > 0 ? day.grossSales / day.ordersCount : 0.0;
        String benchmark = 'Steady Sales';
        if (data.dailyList.length > 1) {
          if (day.grossSales >= avgDailySales * 1.20) {
            benchmark = 'High-Sales Day (Busiest)';
          } else if (day.grossSales <= avgDailySales * 0.80) {
            benchmark = 'Low-Sales Day (Quiet)';
          }
        } else {
          benchmark = 'Daily Operations';
        }

        appendStyledRow(dailySheet, [
          excel_pkg.TextCellValue(day.dateStr),
          excel_pkg.TextCellValue(day.dayOfWeek),
          excel_pkg.IntCellValue(day.ordersCount),
          excel_pkg.IntCellValue(day.itemsSold),
          excel_pkg.DoubleCellValue(day.grossSales),
          excel_pkg.DoubleCellValue(dayAov),
          excel_pkg.TextCellValue(benchmark),
        ]);
      }

      final totalDailySales = data.dailyList.fold(0.0, (sum, d) => sum + d.grossSales);
      final totalDailyOrders = data.dailyList.fold(0, (sum, d) => sum + d.ordersCount);
      final totalDailyItems = data.dailyList.fold(0, (sum, d) => sum + d.itemsSold);
      final overallDailyAov = totalDailyOrders > 0 ? totalDailySales / totalDailyOrders : 0.0;

      appendStyledRow(dailySheet, [
        excel_pkg.TextCellValue('Period Total / Daily Average'),
        excel_pkg.TextCellValue('${data.dailyList.length} Operating Days'),
        excel_pkg.IntCellValue(totalDailyOrders),
        excel_pkg.IntCellValue(totalDailyItems),
        excel_pkg.DoubleCellValue(totalDailySales),
        excel_pkg.DoubleCellValue(overallDailyAov),
        excel_pkg.TextCellValue('Balanced'),
      ], style: totalRowStyle);

      // ────────────────────────────────────────────────────────────────────────
      // TAB 3: MEAL RUSH HOURS
      // ────────────────────────────────────────────────────────────────────────
      final hourlySheet = excel['Meal Rush Hours'];
      hourlySheet.setColumnWidth(0, 30.0);
      hourlySheet.setColumnWidth(1, 25.0);
      hourlySheet.setColumnWidth(2, 16.0);
      hourlySheet.setColumnWidth(3, 16.0);
      hourlySheet.setColumnWidth(4, 20.0);
      hourlySheet.setColumnWidth(5, 18.0);
      hourlySheet.setColumnWidth(6, 28.0);

      appendStyledRow(hourlySheet, [
        excel_pkg.TextCellValue('Service Period'),
        excel_pkg.TextCellValue('Time Window'),
        excel_pkg.TextCellValue('Orders Handled'),
        excel_pkg.TextCellValue('Dishes Served'),
        excel_pkg.TextCellValue('Total Sales (PHP)'),
        excel_pkg.TextCellValue('Sales Share (%)'),
        excel_pkg.TextCellValue('Store Traffic Level'),
      ], style: headerStyle);

      for (var bucket in data.hourlyList) {
        final contribution = data.grossRevenue > 0 ? (bucket.grossSales / data.grossRevenue) * 100 : 0.0;
        final orders = bucket.ordersCount;
        String traffic = 'Quiet / Off-Peak Hours';
        if (orders >= 10 || (orders >= 4 && contribution >= 25.0)) {
          traffic = 'Peak Rush Hour (High Traffic)';
        } else if (orders >= 5 || (orders >= 2 && contribution >= 15.0)) {
          traffic = 'Moderate Service';
        }

        appendStyledRow(hourlySheet, [
          excel_pkg.TextCellValue(bucket.servicePeriod),
          excel_pkg.TextCellValue(bucket.timeWindow),
          excel_pkg.IntCellValue(bucket.ordersCount),
          excel_pkg.IntCellValue(bucket.itemsSold),
          excel_pkg.DoubleCellValue(bucket.grossSales),
          excel_pkg.TextCellValue('${contribution.toStringAsFixed(1)}%'),
          excel_pkg.TextCellValue(traffic),
        ]);
      }

      // ────────────────────────────────────────────────────────────────────────
      // TAB 4: MENU PERFORMANCE
      // ────────────────────────────────────────────────────────────────────────
      final menuSheet = excel['Menu Performance'];
      menuSheet.setColumnWidth(0, 10.0);
      menuSheet.setColumnWidth(1, 30.0);
      menuSheet.setColumnWidth(2, 22.0);
      menuSheet.setColumnWidth(3, 16.0);
      menuSheet.setColumnWidth(4, 20.0);
      menuSheet.setColumnWidth(5, 16.0);
      menuSheet.setColumnWidth(6, 32.0);

      appendStyledRow(menuSheet, [excel_pkg.TextCellValue('TOP SELLING DISHES & BEST SELLERS')], style: titleStyle);
      appendStyledRow(menuSheet, [
        excel_pkg.TextCellValue('Rank'),
        excel_pkg.TextCellValue('Dish / Item Name'),
        excel_pkg.TextCellValue('Menu Category'),
        excel_pkg.TextCellValue('Quantity Sold'),
        excel_pkg.TextCellValue('Total Sales (PHP)'),
        excel_pkg.TextCellValue('Sales Share (%)'),
        excel_pkg.TextCellValue('Sales Status'),
      ], style: headerStyle);

      final topPerformers = data.bestSellers;
      int rank = 1;
      for (var item in topPerformers) {
        final contribution = data.grossRevenue > 0 ? (item.revenue / data.grossRevenue) * 100 : 0.0;
        appendStyledRow(menuSheet, [
          excel_pkg.IntCellValue(rank++),
          excel_pkg.TextCellValue(item.name),
          excel_pkg.TextCellValue(item.category),
          excel_pkg.IntCellValue(item.quantity),
          excel_pkg.DoubleCellValue(item.revenue),
          excel_pkg.TextCellValue('${contribution.toStringAsFixed(1)}%'),
          excel_pkg.TextCellValue('Best Seller / High Demand'),
        ]);
      }

      appendStyledRow(menuSheet, []);
      appendStyledRow(menuSheet, [excel_pkg.TextCellValue('SLOW MOVING & LEAST ORDERED DISHES')], style: titleStyle);
      appendStyledRow(menuSheet, [
        excel_pkg.TextCellValue('Rank'),
        excel_pkg.TextCellValue('Dish / Item Name'),
        excel_pkg.TextCellValue('Menu Category'),
        excel_pkg.TextCellValue('Quantity Sold'),
        excel_pkg.TextCellValue('Total Sales (PHP)'),
        excel_pkg.TextCellValue('Sales Share (%)'),
        excel_pkg.TextCellValue('Manager Recommendation'),
      ], style: headerStyle);

      final bestSellerNames = data.bestSellers.map((b) => b.name).toSet();
      final bottomItems = data.lowSellers
          .where((item) => !bestSellerNames.contains(item.name) || item.quantity == 0)
          .toList();
      int lowRank = 1;
      for (var item in bottomItems) {
        final contribution = data.grossRevenue > 0 ? (item.revenue / data.grossRevenue) * 100 : 0.0;
        String rec = 'Moderate / Steady Sales';
        if (item.quantity == 0) {
          rec = 'Zero Orders - Consider Promo or Review Ingredients';
        } else if (item.quantity <= 2) {
          rec = 'Low Demand - Feature in Combos / Daily Specials';
        }
        appendStyledRow(menuSheet, [
          excel_pkg.IntCellValue(lowRank++),
          excel_pkg.TextCellValue(item.name),
          excel_pkg.TextCellValue(item.category),
          excel_pkg.IntCellValue(item.quantity),
          excel_pkg.DoubleCellValue(item.revenue),
          excel_pkg.TextCellValue('${contribution.toStringAsFixed(1)}%'),
          excel_pkg.TextCellValue(rec),
        ]);
      }

      // ────────────────────────────────────────────────────────────────────────
      // TAB 5: TRANSACTIONS & AUDIT LOG
      // ────────────────────────────────────────────────────────────────────────
      if (data.isEventOnly) {
        final logSheet = excel['Event Bookings Log'];
        logSheet.setColumnWidth(0, 16.0);
        logSheet.setColumnWidth(1, 24.0);
        logSheet.setColumnWidth(2, 25.0);
        logSheet.setColumnWidth(3, 18.0);
        logSheet.setColumnWidth(4, 22.0);
        logSheet.setColumnWidth(5, 14.0);
        logSheet.setColumnWidth(6, 20.0);
        logSheet.setColumnWidth(7, 35.0);
        logSheet.setColumnWidth(8, 16.0);
        logSheet.setColumnWidth(9, 20.0);
        logSheet.setColumnWidth(10, 22.0);
        logSheet.setColumnWidth(11, 22.0);
        logSheet.setColumnWidth(12, 18.0);
        logSheet.setColumnWidth(13, 18.0);

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('Booking Ref'),
          excel_pkg.TextCellValue('Event Date & Time'),
          excel_pkg.TextCellValue('Host / Client Name'),
          excel_pkg.TextCellValue('Contact Number'),
          excel_pkg.TextCellValue('Event Type / Occasion'),
          excel_pkg.TextCellValue('Guests (Pax)'),
          excel_pkg.TextCellValue('Table / Venue Area'),
          excel_pkg.TextCellValue('Catering Menu / Inclusions'),
          excel_pkg.TextCellValue('Payment Option'),
          excel_pkg.TextCellValue('Deposit Paid (PHP)'),
          excel_pkg.TextCellValue('Remaining Balance (PHP)'),
          excel_pkg.TextCellValue('Total Contract (PHP)'),
          excel_pkg.TextCellValue('Payment Method'),
          excel_pkg.TextCellValue('Booking Status'),
        ], style: headerStyle);

        for (int i = 0; i < data.transactions.length; i++) {
          if (i > 0 && i % 40 == 0) {
            statusNotifier.value = 'Isinusulat ang event bookings (${i + 1}/${data.transactions.length})...';
            await Future.delayed(Duration.zero);
          }
          final t = data.transactions[i];
          final date = (t['raw_date'] as DateTime).toLocal();
          final eventDateStr = (t['event_date']?.toString().isNotEmpty == true)
              ? '${t['event_date']} ${t['start_time'] ?? ''}'.trim()
              : DateFormat('yyyy-MM-dd hh:mm a').format(date);
          final ref = t['id']?.toString() ?? '#N/A';
          final host = t['customer']?.toString() ?? 'Guest';
          final phone = (t['customer_phone']?.toString().isNotEmpty == true) ? t['customer_phone'].toString() : '-';
          final eventType = t['event_type']?.toString() ?? 'Banquet Event';
          final guests = (t['number_of_guests'] as num?)?.toInt() ?? 0;
          final location = (t['table_number']?.toString().isNotEmpty == true) ? t['table_number'].toString() : 'Dining Hall';
          final dishes = t['_itemsSummary']?.toString() ?? 'Catering Package';
          final payOption = t['payment_option']?.toString() ?? 'Full';
          final depositPaid = (t['deposit_amount'] as num?)?.toDouble() ?? 0.0;
          final totalContract = (t['total_price'] as num?)?.toDouble() ?? ((t['raw_amount'] as num?)?.toDouble() ?? 0.0);
          final remBalance = (t['remaining_balance'] as num?)?.toDouble() ?? (totalContract > depositPaid ? (totalContract - depositPaid) : 0.0);
          final paymentMethod = t['payment_method']?.toString() ?? 'Cash/Card';
          final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
          final status = isValidRev ? (t['status']?.toString() ?? 'Confirmed') : '${t['status'] ?? 'Cancelled'} (Excluded)';

          appendStyledRow(logSheet, [
            excel_pkg.TextCellValue(ref),
            excel_pkg.TextCellValue(eventDateStr),
            excel_pkg.TextCellValue(host),
            excel_pkg.TextCellValue(phone),
            excel_pkg.TextCellValue(eventType),
            excel_pkg.IntCellValue(guests),
            excel_pkg.TextCellValue(location),
            excel_pkg.TextCellValue(dishes),
            excel_pkg.TextCellValue(payOption),
            excel_pkg.DoubleCellValue(depositPaid),
            excel_pkg.DoubleCellValue(remBalance),
            excel_pkg.DoubleCellValue(totalContract),
            excel_pkg.TextCellValue(paymentMethod),
            excel_pkg.TextCellValue(status),
          ]);
        }

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('TOTAL CATERING BOOKINGS'),
          excel_pkg.TextCellValue('${data.transactions.length} Bookings'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('${data.totalQuantitySold} Dishes / Units'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.DoubleCellValue(data.grossRevenue),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('Balanced'),
        ], style: totalRowStyle);
      } else if (data.isAdvanceOnly) {
        final logSheet = excel['Advance Orders Log'];
        logSheet.setColumnWidth(0, 16.0);
        logSheet.setColumnWidth(1, 22.0);
        logSheet.setColumnWidth(2, 22.0);
        logSheet.setColumnWidth(3, 24.0);
        logSheet.setColumnWidth(4, 18.0);
        logSheet.setColumnWidth(5, 18.0);
        logSheet.setColumnWidth(6, 14.0);
        logSheet.setColumnWidth(7, 35.0);
        logSheet.setColumnWidth(8, 18.0);
        logSheet.setColumnWidth(9, 20.0);
        logSheet.setColumnWidth(10, 20.0);
        logSheet.setColumnWidth(11, 18.0);

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('Order Ref'),
          excel_pkg.TextCellValue('Order Placed Date'),
          excel_pkg.TextCellValue('Fulfillment Date & Time'),
          excel_pkg.TextCellValue('Customer Name'),
          excel_pkg.TextCellValue('Contact Number'),
          excel_pkg.TextCellValue('Fulfillment Type'),
          excel_pkg.TextCellValue('Total Items'),
          excel_pkg.TextCellValue('Dishes Ordered'),
          excel_pkg.TextCellValue('Payment Method'),
          excel_pkg.TextCellValue('Total Paid (PHP)'),
          excel_pkg.TextCellValue('Processed By'),
          excel_pkg.TextCellValue('Order Status'),
        ], style: headerStyle);

        for (int i = 0; i < data.transactions.length; i++) {
          if (i > 0 && i % 40 == 0) {
            statusNotifier.value = 'Writing advance orders (${i + 1}/${data.transactions.length})...';
            await Future.delayed(Duration.zero);
          }
          final t = data.transactions[i];
          final date = (t['raw_date'] as DateTime).toLocal();
          final placedDateStr = DateFormat('yyyy-MM-dd hh:mm a').format(date);
          final fulfillDateStr = (t['order_date']?.toString().isNotEmpty == true)
              ? '${t['order_date']} ${t['order_time'] ?? ''}'.trim()
              : placedDateStr;
          final ref = t['id']?.toString() ?? '#N/A';
          final customer = t['customer']?.toString() ?? 'Guest';
          final phone = (t['customer_phone']?.toString().isNotEmpty == true) ? t['customer_phone'].toString() : '-';
          final orderType = t['order_type']?.toString() ?? 'Pickup';
          final itemsCount = (t['_itemsCount'] as int?) ?? 1;
          final dishes = t['_itemsSummary']?.toString() ?? 'Pre-Order Items';
          final paymentMethod = t['payment_method']?.toString() ?? 'Online / Cash';
          final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
          final revAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
          final processedBy = t['processed_by']?.toString() ?? 'Staff';
          final status = isValidRev ? (t['status']?.toString() ?? 'Completed') : '${t['status'] ?? 'Cancelled'} (Excluded)';

          appendStyledRow(logSheet, [
            excel_pkg.TextCellValue(ref),
            excel_pkg.TextCellValue(placedDateStr),
            excel_pkg.TextCellValue(fulfillDateStr),
            excel_pkg.TextCellValue(customer),
            excel_pkg.TextCellValue(phone),
            excel_pkg.TextCellValue(orderType),
            excel_pkg.IntCellValue(itemsCount),
            excel_pkg.TextCellValue(dishes),
            excel_pkg.TextCellValue(paymentMethod),
            excel_pkg.DoubleCellValue(revAmt),
            excel_pkg.TextCellValue(processedBy),
            excel_pkg.TextCellValue(status),
          ]);
        }

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('TOTAL ADVANCE ORDERS'),
          excel_pkg.TextCellValue('${data.transactions.length} Orders'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.IntCellValue(data.totalQuantitySold),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.DoubleCellValue(data.grossRevenue),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('Balanced'),
        ], style: totalRowStyle);
      } else {
        final logSheet = excel['Orders & Receipts Log'];
        logSheet.setColumnWidth(0, 22.0);
        logSheet.setColumnWidth(1, 16.0);
        logSheet.setColumnWidth(2, 18.0);
        logSheet.setColumnWidth(3, 24.0);
        logSheet.setColumnWidth(4, 18.0);
        logSheet.setColumnWidth(5, 14.0);
        logSheet.setColumnWidth(6, 35.0);
        logSheet.setColumnWidth(7, 20.0);
        logSheet.setColumnWidth(8, 20.0);
        logSheet.setColumnWidth(9, 18.0);

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('Date & Time'),
          excel_pkg.TextCellValue('Receipt / Order Ref'),
          excel_pkg.TextCellValue('Order Type'),
          excel_pkg.TextCellValue('Customer Name'),
          excel_pkg.TextCellValue('Payment Method'),
          excel_pkg.TextCellValue('Total Items'),
          excel_pkg.TextCellValue('Dishes Ordered'),
          excel_pkg.TextCellValue('Total Paid (PHP)'),
          excel_pkg.TextCellValue('Cashier / Staff'),
          excel_pkg.TextCellValue('Order Status'),
        ], style: headerStyle);

        for (int i = 0; i < data.transactions.length; i++) {
          if (i > 0 && i % 40 == 0) {
            statusNotifier.value = 'Writing transactions (${i + 1}/${data.transactions.length})...';
            await Future.delayed(Duration.zero);
          }
          final t = data.transactions[i];
          final date = (t['raw_date'] as DateTime).toLocal();
          final dateFormatted = DateFormat('yyyy-MM-dd hh:mm a').format(date);
          final ref = t['id']?.toString() ?? '#N/A';
          final isPosTakeout = (t['is_pos_takeout'] as bool?) ?? false;
          final channel = isPosTakeout
              ? 'Take-out'
              : (t['type'] == 'Regular'
                  ? 'Dine-in / Walk-in'
                  : (t['type'] == 'Advance' ? 'Pre-Order' : 'Event Catering'));
          final customer = t['customer']?.toString() ?? 'Guest';
          final payment = t['payment_method']?.toString() ?? 'Cash';
          final itemsCount = (t['_itemsCount'] as int?) ?? 1;
          final itemsSummary = t['_itemsSummary']?.toString() ?? 'Standard Order';
          final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
          final revAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
          final handledBy = t['processed_by']?.toString() ?? 'Cashier Staff';
          final status = isValidRev ? (t['status']?.toString() ?? 'Completed') : '${t['status'] ?? 'Void'} (Excluded)';

          appendStyledRow(logSheet, [
            excel_pkg.TextCellValue(dateFormatted),
            excel_pkg.TextCellValue(ref),
            excel_pkg.TextCellValue(channel),
            excel_pkg.TextCellValue(customer),
            excel_pkg.TextCellValue(payment),
            excel_pkg.IntCellValue(itemsCount),
            excel_pkg.TextCellValue(itemsSummary),
            excel_pkg.DoubleCellValue(revAmt),
            excel_pkg.TextCellValue(handledBy),
            excel_pkg.TextCellValue(status),
          ]);
        }

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue('TOTAL TRANSACTIONS'),
          excel_pkg.TextCellValue('${data.transactions.length} Orders'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('-'),
          excel_pkg.IntCellValue(data.totalQuantitySold),
          excel_pkg.TextCellValue('-'),
          excel_pkg.DoubleCellValue(data.grossRevenue),
          excel_pkg.TextCellValue('-'),
          excel_pkg.TextCellValue('Balanced'),
        ], style: totalRowStyle);
      }

      statusNotifier.value = 'Ine-encode ang Excel spreadsheet...';
      await Future.delayed(Duration.zero);

      final List<int>? excelBytes = excel.save();
      if (excelBytes == null) {
        throw Exception('Failed to generate Excel file');
      }
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      if (mounted) Navigator.pop(context);

      // 1. Direct Web Download
      if (kIsWeb) {
        final downloaded = downloadBinaryFile(
          bytes,
          '$fileName.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (downloaded) {
          GlobalMessenger.showSuccess('Sales Report Excel downloaded: $fileName.xlsx');
          return;
        }
      } else {
        // Desktop Windows direct save to Downloads folder
        try {
          if (Platform.isWindows) {
            final userProfile = Platform.environment['USERPROFILE'];
            if (userProfile != null) {
              final downloadsDir = Directory('$userProfile\\Downloads');
              if (downloadsDir.existsSync()) {
                final targetPath = '${downloadsDir.path}\\$fileName.xlsx';
                final file = File(targetPath);
                await file.writeAsBytes(bytes);
                GlobalMessenger.showSuccess('Sales Report Excel saved to Downloads: $fileName.xlsx');
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Desktop direct save fallback: $e');
        }
      }

      // Fallback: FilePicker
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow Restaurant Sales Report Excel',
        fileName: '$fileName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );

      if (outputFile != null) {
        if (!kIsWeb) {
          try {
            final finalPath = outputFile.toLowerCase().endsWith('.xlsx') ? outputFile : '$outputFile.xlsx';
            final file = File(finalPath);
            if (!file.existsSync() || file.lengthSync() == 0) {
              await file.writeAsBytes(bytes);
            }
          } catch (e) {
            debugPrint('Desktop file write fallback: $e');
          }
        }
        GlobalMessenger.showSuccess('Sales Report Excel na-save: $fileName.xlsx');
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.isCurrent);
      GlobalMessenger.showError('Excel export failed: $e');
    } finally {
      statusNotifier.dispose();
    }
  }
  // Cache fonts so they are only downloaded once per session
  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;

  Future<void> _exportToPDF(
    List<Map<String, dynamic>> transactions,
    String fileName, {
    Map<String, dynamic>? metrics,
    bool directDownload = false,
    Set<String>? channelFilter,
  }) async {
    final statusNotifier = ValueNotifier<String>('Retrieving report data…');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: statusNotifier,
        builder: (_, status, __) => Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.adminPrimaryAccent),
                  const SizedBox(height: 16),
                  Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please wait, processing securely…',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    late Uint8List pdfBytes;
    try {
      // Step 1: Fetch & process data
      final data = await _prepareReportData(
        transactions,
        metrics,
        channelFilter: channelFilter,
        statusNotifier: statusNotifier,
      );
      if (data == null) {
        if (mounted) Navigator.pop(context);
        statusNotifier.dispose();
        return;
      }
      final reportData = data;

      // Step 2: Load fonts (cached after first download)
      statusNotifier.value = 'Loading report fonts…';
      await Future.delayed(Duration.zero);
      pw.ThemeData? theme;
      try {
        _cachedFontRegular ??= await PdfGoogleFonts.robotoRegular();
        _cachedFontBold ??= await PdfGoogleFonts.robotoBold();
        theme = pw.ThemeData.withFont(
          base: _cachedFontRegular!,
          bold: _cachedFontBold!,
        );
      } catch (_) {}

      // Step 3: Build PDF structure
      statusNotifier.value = 'Building PDF layout…';
      await Future.delayed(Duration.zero);

      final pdf = pw.Document(theme: theme);
      const primaryColor = PdfColor.fromInt(0xFF14332E);
      const goldColor = PdfColor.fromInt(0xFFD4AF37);
      const greyHeaderColor = PdfColor.fromInt(0xFFF1F5F9);
      const alternateRowColor = PdfColor.fromInt(0xFFF8FAFC);
      const borderColor = PdfColor.fromInt(0xFFE2E8F0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          maxPages: 50,
          header: (pw.Context ctx) => _buildPdfHeader(reportData, primaryColor, goldColor),
          footer: (pw.Context ctx) => _buildPdfFooter(ctx, reportData),
          build: (pw.Context ctx) => [
            _buildPdfSummaryCards(reportData, primaryColor, goldColor, borderColor),
            pw.SizedBox(height: 8),
            _buildPdfCombinedSalesChart(reportData, primaryColor, goldColor, borderColor),
            pw.SizedBox(height: 8),
            _buildPdfVisualizations(reportData, primaryColor, goldColor, borderColor),
            pw.SizedBox(height: 8),
            _buildPdfPaymentDistribution(reportData, primaryColor, goldColor, borderColor),
            pw.SizedBox(height: 8),
            _buildPdfExecutiveExplanation(reportData, primaryColor, goldColor, borderColor),
            pw.SizedBox(height: 8),
            ..._buildPdfDailyTableWidgets(reportData, primaryColor, greyHeaderColor, alternateRowColor, borderColor),
            pw.SizedBox(height: 8),
            ..._buildPdfHourlyTableWidgets(reportData, primaryColor, greyHeaderColor, alternateRowColor, borderColor),
            pw.SizedBox(height: 8),
            ..._buildPdfBestSellersTableWidgets(reportData, primaryColor, greyHeaderColor, alternateRowColor, borderColor),
            pw.SizedBox(height: 8),
            ..._buildPdfLowSellersTableWidgets(reportData, primaryColor, greyHeaderColor, alternateRowColor, borderColor),
            pw.SizedBox(height: 8),
            ..._buildPdfOrdersLogTableWidgets(reportData, primaryColor, greyHeaderColor, alternateRowColor, borderColor),
            pw.SizedBox(height: 12),
            _buildPdfSignOffBlock(reportData, primaryColor, borderColor),
          ],
        ),
      );

      // Step 4: Serialize to bytes (CPU-heavy)
      statusNotifier.value = 'Encoding PDF file…';
      await Future.delayed(Duration.zero);
      pdfBytes = await pdf.save();

      // Step 5: Save / open
      statusNotifier.value = directDownload ? 'Saving PDF file…' : 'Opening print dialog…';
      await Future.delayed(Duration.zero);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      statusNotifier.dispose();
      GlobalMessenger.showError('PDF generation failed: $e');
      return;
    }

    // Close dialog before showing file picker / print preview
    if (mounted) Navigator.pop(context);
    statusNotifier.dispose();

    try {
      if (directDownload) {
        // 1. Direct Web Download
        if (kIsWeb) {
          final downloaded = downloadBinaryFile(
            pdfBytes,
            '$fileName.pdf',
            'application/pdf',
          );
          if (downloaded) {
            GlobalMessenger.showSuccess('Sales Report PDF downloaded: $fileName.pdf');
            return;
          }
        } else {
          // Direct Desktop Download to Downloads folder
          try {
            if (Platform.isWindows) {
              final userProfile = Platform.environment['USERPROFILE'];
              if (userProfile != null) {
                final downloadsDir = Directory('$userProfile\\Downloads');
                if (downloadsDir.existsSync()) {
                  final targetPath = '${downloadsDir.path}\\$fileName.pdf';
                  final file = File(targetPath);
                  await file.writeAsBytes(pdfBytes);
                  GlobalMessenger.showSuccess('Sales Report PDF saved to Downloads: $fileName.pdf');
                  return;
                }
              }
            }
          } catch (e) {
            debugPrint('Desktop PDF write fallback: $e');
          }
        }

        // Fallback: FilePicker
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Yang Chow Restaurant Sales Report PDF',
          fileName: '$fileName.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
        );

        if (outputFile != null) {
          if (!kIsWeb) {
            try {
              final finalPath = outputFile.toLowerCase().endsWith('.pdf') ? outputFile : '$outputFile.pdf';
              final file = File(finalPath);
              if (!file.existsSync() || file.lengthSync() == 0) {
                await file.writeAsBytes(pdfBytes);
              }
            } catch (e) {
              debugPrint('Desktop file write fallback: $e');
            }
          }
          GlobalMessenger.showSuccess('Sales Report PDF na-save: $fileName.pdf');
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: '$fileName.pdf',
        );
      }
    } catch (e) {
      GlobalMessenger.showError('PDF save failed: $e');
    }
  }

  pw.Widget _buildPdfHeader(_ProcessedReportData data, PdfColor primaryColor, PdfColor goldColor) {
    String headerSubtitle;
    String channelBadge;
    if (data.isEventOnly) {
      headerSubtitle = 'OFFICIAL AUDIT - EVENT CATERING & BANQUETS (EXECUTIVE COPY)';
      channelBadge = 'Channel: Event Catering Only';
    } else if (data.isAdvanceOnly) {
      headerSubtitle = 'OFFICIAL AUDIT - ADVANCE ORDERS & PRE-ORDERS (EXECUTIVE COPY)';
      channelBadge = 'Channel: Advance Orders Only';
    } else if (data.isRegularOnly) {
      headerSubtitle = 'OFFICIAL AUDIT - WALK-IN & DINE-IN COUNTER SALES (EXECUTIVE COPY)';
      channelBadge = 'Channel: Walk-in / Dine-in';
    } else {
      headerSubtitle = 'OFFICIAL STORE SALES & FINANCIAL AUDIT (EXECUTIVE COPY)';
      channelBadge = 'Channel: All Channels';
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.appName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.4,
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                'CLA TOWN CENTER MALL, PAGSANJAN, LAGUNA',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
              ),
              pw.Text(
                headerSubtitle,
                style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Period: ${data.reportPeriodLabel}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.Text(channelBadge, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.Text('Coverage: ${data.dateRangeStr}', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                pw.Text('Generated: ${DateFormat('yyyy-MM-dd h:mm a').format(data.generatedAt)}', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context ctx, _ProcessedReportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Yang Chow Restaurant - Operations Management Report', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static final NumberFormat _pdfMoneyFormatter = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _pdfIntegerFormatter = NumberFormat('#,##0', 'en_US');

  String _formatPdfMoney(double value) {
    return 'PHP ${_pdfMoneyFormatter.format(value)}';
  }

  String _formatPdfCount(int value) {
    return _pdfIntegerFormatter.format(value);
  }

  pw.Widget _buildPdfSummaryCards(_ProcessedReportData data, PdfColor primaryColor, PdfColor goldColor, PdfColor borderColor) {
    pw.Widget metricBox(String label, String value, String sub) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 1),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600)),
          ],
        ),
      );
    }

    if (data.isEventOnly) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Gross Catering Sales', _formatPdfMoney(data.grossRevenue), 'Total catering revenue')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Event Bookings', '${_formatPdfCount(data.totalOrders)} Bookings', 'Confirmed & serviced')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Average Event Value', _formatPdfMoney(data.avgOrderValue), 'Mean spend per event')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Booking Status', '${_formatPdfCount(data.totalOrders)} Confirmed', data.eventCancelRate > 10 ? 'Cancellations Recorded' : 'Normal Operations')),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Buffet Courses / Dishes', '${_formatPdfCount(data.totalQuantitySold)} Dishes', 'Total courses prepared')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Clients & Attendees', '${_formatPdfCount(data.uniqueCustomers)} Pax', 'Confirmed attendee headcount')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Sales Channel', 'Event Catering', 'Special banquet bookings')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Audit Status', 'Verified & Balanced', 'Manager financial audit')),
            ],
          ),
        ],
      );
    } else if (data.isAdvanceOnly) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Gross Pre-Order Sales', _formatPdfMoney(data.grossRevenue), 'Total pre-orders revenue')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Pre-Orders Handled', '${_formatPdfCount(data.totalOrders)} Orders', 'Scheduled & fulfilled')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Average Spend (AOV)', _formatPdfMoney(data.avgOrderValue), 'Mean spend per pre-order')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Order Status', '${_formatPdfCount(data.totalOrders)} Fulfilled', data.advCancelRate > 10 ? 'Cancellations Recorded' : 'Normal Operations')),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Dishes Packaged', '${_formatPdfCount(data.totalQuantitySold)} Dishes', 'Total kitchen units')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Pre-Order Customers', '${_formatPdfCount(data.uniqueCustomers)} Guests', 'Scheduled pickup headcount')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Sales Channel', 'Advance Orders', 'Scheduled pickup & takeout')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Audit Status', 'Verified & Balanced', 'Manager financial audit')),
            ],
          ),
        ],
      );
    } else if (data.isRegularOnly) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Gross Walk-in Sales', _formatPdfMoney(data.grossRevenue), 'Total counter revenue')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Counter Receipts', '${_formatPdfCount(data.totalOrders)} Orders', 'Completed POS tickets')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Average Spend (AOV)', _formatPdfMoney(data.avgOrderValue), 'Mean spend per ticket')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Dishes Served', '${_formatPdfCount(data.totalQuantitySold)} Dishes', 'Kitchen units served')),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(child: metricBox('Diners / Guests Served', '${_formatPdfCount(data.uniqueCustomers)} Guests', 'POS covers & headcount')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Kitchen Alerts', '${data.lowStockItems} Low Stock', 'Inventory threshold')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Service Schedule', '10:00 AM - 08:00 PM', 'Daily operating hours')),
              pw.SizedBox(width: 6),
              pw.Expanded(child: metricBox('Audit Status', 'Verified & Balanced', 'Manager financial audit')),
            ],
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(child: metricBox('Gross Total Sales', _formatPdfMoney(data.grossRevenue), 'Total store gross sales')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Dine-in / Walk-in', _formatPdfMoney(data.walkInRevenue), '${_formatPdfCount(data.walkInOrders)} orders')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Advance Orders', _formatPdfMoney(data.advanceRevenue), '${_formatPdfCount(data.advanceOrders)} orders')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Event Catering', _formatPdfMoney(data.reservationRevenue), '${_formatPdfCount(data.reservationOrders)} bookings')),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(child: metricBox('Total Orders Handled', '${_formatPdfCount(data.totalOrders)} Orders', 'Completed tickets')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Total Dishes Sold', '${_formatPdfCount(data.totalQuantitySold)} Dishes', 'Total kitchen units')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Average Spend (AOV)', _formatPdfMoney(data.avgOrderValue), 'Mean spend per order')),
            pw.SizedBox(width: 6),
            pw.Expanded(child: metricBox('Total Guests Served', '${_formatPdfCount(data.uniqueCustomers)} Guests', '${data.lowStockItems} low stock alerts')),
          ],
        ),
      ],
    );
  }

  String _formatPdfShortMoney(double amount) {
    if (amount >= 1000000) {
      return 'P${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'P${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return 'P${amount.toInt()}';
    }
  }

  pw.Widget _buildPdfCombinedSalesChart(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor borderColor,
  ) {
    final dailyList = data.dailyList;
    if (dailyList.isEmpty) return pw.SizedBox();

    // 1. Calculate scales
    double maxSales = 0.0;
    int maxOrders = 0;
    for (final d in dailyList) {
      if (d.grossSales > maxSales) maxSales = d.grossSales;
      if (d.ordersCount > maxOrders) maxOrders = d.ordersCount;
    }
    if (maxSales <= 0) maxSales = 1000.0;
    if (maxOrders <= 0) maxOrders = 10;

    // Add headroom
    final double salesCeiling = maxSales * 1.15;
    final double ordersCeiling = (maxOrders * 1.25).toDouble();

    // Format Y-axis tick values
    final String topSalesLabel = _formatPdfShortMoney(salesCeiling);
    final String midSalesLabel = _formatPdfShortMoney(salesCeiling / 2);
    const String zeroSalesLabel = 'P0';

    final String topOrdersLabel = '${ordersCeiling.toInt()}';
    final String midOrdersLabel = '${(ordersCeiling / 2).toInt()}';
    const String zeroOrdersLabel = '0';

    const barColor = PdfColor.fromInt(0xFF14332E);       // Deep emerald
    const barTopColor = PdfColor.fromInt(0xFF0D9488);    // Teal top border
    const lineColor = PdfColor.fromInt(0xFFD97706);      // Amber gold line
    const dotColor = PdfColor.fromInt(0xFFF59E0B);       // Bright amber dot
    const gridLineColor = PdfColor.fromInt(0xFFE2E8F0);  // Slate grid

    const double chartHeight = 70.0;
    final int n = dailyList.length;

    // Determine label step for X-axis
    final int labelStep = n > 20 ? 3 : (n > 10 ? 2 : 1);

    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.TableBorder.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header & Legend ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GROSS ANALYTICS & TRENDS (COMBINED BAR & LINE GRAPH)',
                    style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Daily Gross Sales (Bars in PHP) vs. Transaction Volume / Customer Orders (Line Graph)',
                    style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.grey700),
                  ),
                ],
              ),
              // Legend badges
              pw.Row(
                children: [
                  pw.Container(
                    width: 7,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                      color: barColor,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(1)),
                    ),
                  ),
                  pw.SizedBox(width: 3),
                  pw.Text(
                    'Gross Sales (Bar)',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Container(width: 8, height: 1.5, color: lineColor),
                  pw.SizedBox(width: 2),
                  pw.Container(
                    width: 4,
                    height: 4,
                    decoration: const pw.BoxDecoration(color: dotColor, shape: pw.BoxShape.circle),
                  ),
                  pw.SizedBox(width: 3),
                  pw.Text(
                    'Order Volume (Line)',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: lineColor),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 5),

          // ── Chart Area ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Y-axis (Sales P)
              pw.Container(
                height: chartHeight,
                width: 32,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(topSalesLabel, style: const pw.TextStyle(fontSize: 5.0, color: PdfColors.grey700)),
                    pw.Text(midSalesLabel, style: const pw.TextStyle(fontSize: 5.0, color: PdfColors.grey700)),
                    pw.Text(zeroSalesLabel, style: const pw.TextStyle(fontSize: 5.0, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),

              // Canvas + X-Axis Day Numbers
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: chartHeight,
                      child: pw.CustomPaint(
                        size: const PdfPoint(460, chartHeight),
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          // Grid lines (Top, Mid, Base)
                          canvas.setStrokeColor(gridLineColor);
                          canvas.setLineWidth(0.5);

                          canvas.drawLine(0, size.y, size.x, size.y);
                          canvas.strokePath();

                          canvas.drawLine(0, size.y / 2, size.x, size.y / 2);
                          canvas.strokePath();

                          canvas.drawLine(0, 0, size.x, 0);
                          canvas.strokePath();

                          if (n == 0) return;

                          final double slotW = size.x / n;
                          final double barW = (slotW * 0.55).clamp(2.0, 14.0);

                          // 1. Draw Bars (Sales)
                          for (int i = 0; i < n; i++) {
                            final d = dailyList[i];
                            final double ratio = (d.grossSales / salesCeiling).clamp(0.0, 1.0);
                            final double barH = (ratio * (size.y - 4)).clamp(0.0, size.y);
                            final double slotCenterX = (i + 0.5) * slotW;
                            final double barLeft = slotCenterX - (barW / 2);

                            if (barH > 0) {
                              canvas.drawRect(barLeft, 0, barW, barH);
                              canvas.setFillColor(barColor);
                              canvas.fillPath();

                              canvas.drawLine(barLeft, barH, barLeft + barW, barH);
                              canvas.setStrokeColor(barTopColor);
                              canvas.setLineWidth(0.8);
                              canvas.strokePath();
                            }
                          }

                          // 2. Draw Line & Points (Orders Count)
                          final List<PdfPoint> points = [];
                          for (int i = 0; i < n; i++) {
                            final d = dailyList[i];
                            final double ratio = (d.ordersCount / ordersCeiling).clamp(0.0, 1.0);
                            final double dotY = (ratio * (size.y - 6)).clamp(2.0, size.y - 2);
                            final double slotCenterX = (i + 0.5) * slotW;
                            points.add(PdfPoint(slotCenterX, dotY));
                          }

                          if (points.isNotEmpty) {
                            canvas.moveTo(points.first.x, points.first.y);
                            for (int i = 1; i < points.length; i++) {
                              canvas.lineTo(points[i].x, points[i].y);
                            }
                            canvas.setStrokeColor(lineColor);
                            canvas.setLineWidth(1.5);
                            canvas.strokePath();

                            for (final p in points) {
                              canvas.drawEllipse(p.x, p.y, 2.0, 2.0);
                              canvas.setFillColor(dotColor);
                              canvas.fillPath();
                              canvas.drawEllipse(p.x, p.y, 2.0, 2.0);
                              canvas.setStrokeColor(PdfColors.white);
                              canvas.setLineWidth(0.5);
                              canvas.strokePath();
                            }
                          }
                        },
                      ),
                    ),
                    pw.SizedBox(height: 2),

                    // X-Axis day labels
                    pw.Row(
                      children: List.generate(n, (i) {
                        final d = dailyList[i];
                        final dayNum = d.date.day;
                        final bool showLabel = (i % labelStep == 0) || (i == n - 1);
                        return pw.Expanded(
                          child: pw.Center(
                            child: pw.Text(
                              showLabel ? '$dayNum' : '',
                              style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),

              // Right Y-axis (Orders)
              pw.Container(
                height: chartHeight,
                width: 26,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$topOrdersLabel ord', style: const pw.TextStyle(fontSize: 5.0, color: lineColor)),
                    pw.Text('$midOrdersLabel ord', style: const pw.TextStyle(fontSize: 5.0, color: lineColor)),
                    pw.Text('$zeroOrdersLabel ord', style: const pw.TextStyle(fontSize: 5.0, color: lineColor)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3.5),

          // Short explanation box for Combined Chart
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CHART OVERVIEW: ',
                  style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'Correlates daily gross sales (emerald bars, left axis) with completed customer order volume (amber line, right axis) to analyze foot traffic intensity, average spend behavior, and revenue fluctuations across operating days.',
                    style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfVisualizations(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor borderColor,
  ) {
    final double totalRev = data.grossRevenue > 0 ? data.grossRevenue : 1.0;
    final double walkInPct = (data.walkInRevenue / totalRev).clamp(0.0, 1.0);
    final double advPct = (data.advanceRevenue / totalRev).clamp(0.0, 1.0);
    final double eventPct = (data.reservationRevenue / totalRev).clamp(0.0, 1.0);

    int walkInFlex = (walkInPct * 1000).toInt();
    int advFlex = (advPct * 1000).toInt();
    int eventFlex = (eventPct * 1000).toInt();
    if (walkInFlex == 0 && advFlex == 0 && eventFlex == 0) walkInFlex = 1000;

    const walkInColor = PdfColor.fromInt(0xFF14332E); // Deep emerald
    const advColor = PdfColor.fromInt(0xFF2563EB);    // Royal blue
    const eventColor = PdfColor.fromInt(0xFFD97706);  // Amber gold

    // Hourly peak evaluation
    _ReportHourlyBucketRecord? peakHour;
    double maxHourlySales = 0.0;
    for (final h in data.hourlyList) {
      if (h.grossSales > maxHourlySales) {
        maxHourlySales = h.grossSales;
        peakHour = h;
      }
    }
    if (maxHourlySales <= 0) maxHourlySales = 1.0;

    // Top dishes evaluation
    final topDishes = data.bestSellers.take(5).toList();
    double maxDishSales = 0.0;
    for (final d in topDishes) {
      if (d.revenue > maxDishSales) maxDishSales = d.revenue;
    }
    if (maxDishSales <= 0) maxDishSales = 1.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.TableBorder.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header & Scope ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DYNAMIC SALES & OPERATIONS ANALYTICS (EXECUTIVE BREAKDOWN)',
                    style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Sales Channel Distribution | Service Period Demand | Menu Performance',
                    style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFE2E8F0),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                ),
                child: pw.Text(
                  'DYNAMIC VISUAL AUDIT',
                  style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),

          // ── Component 1: Channel & Conversion Breakdown ──
          if (data.isAllChannels || data.activeChannels.length > 1) ...[
            pw.Text(
              '1. Sales Distribution by Channel (Revenue Share):',
              style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 3),
            pw.Container(
              height: 11,
              decoration: const pw.BoxDecoration(
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                color: PdfColor.fromInt(0xFFE2E8F0),
              ),
              child: pw.Row(
                children: [
                  if (walkInFlex > 0)
                    pw.Expanded(
                      flex: walkInFlex,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: walkInColor,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(3),
                            bottomLeft: pw.Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  if (advFlex > 0)
                    pw.Expanded(
                      flex: advFlex,
                      child: pw.Container(
                        color: advColor,
                      ),
                    ),
                  if (eventFlex > 0)
                    pw.Expanded(
                      flex: eventFlex,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: eventColor,
                          borderRadius: const pw.BorderRadius.only(
                            topRight: pw.Radius.circular(3),
                            bottomRight: pw.Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfLegendItem(
                  'Walk-in / Dine-in',
                  walkInColor,
                  '${_formatPdfMoney(data.walkInRevenue)} | ${_formatPdfCount(data.walkInOrders)} orders',
                ),
                _buildPdfLegendItem(
                  'Advance Orders',
                  advColor,
                  '${_formatPdfMoney(data.advanceRevenue)} | ${_formatPdfCount(data.advanceOrders)} orders',
                ),
                _buildPdfLegendItem(
                  'Event Catering',
                  eventColor,
                  '${_formatPdfMoney(data.reservationRevenue)} | ${_formatPdfCount(data.reservationOrders)} bookings',
                ),
              ],
            ),
          ] else ...[
            // Single channel focused summary bar
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    data.isEventOnly
                        ? 'Focused Channel: Event Catering & Special Banquets'
                        : (data.isAdvanceOnly
                            ? 'Focused Channel: Advance Orders & Pre-Scheduled Takeout'
                            : 'Focused Channel: Walk-in Counter & Dine-in Sales'),
                    style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.Text(
                    'Total Sales: ${_formatPdfMoney(data.grossRevenue)} across ${_formatPdfCount(data.totalOrders)} transactions',
                    style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 5),

          // ── Component 3: Two-Column Visual (Rush Hours vs Top 5 Dishes) ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Rush Hours visual bars
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '2. Service Period & Meal Rush Demand:',
                            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          if (peakHour != null && peakHour.grossSales > 0)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFFFEE2E2),
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                              ),
                              child: pw.Text(
                                'PEAK: ${peakHour.servicePeriod.toUpperCase()}',
                                style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFDC2626)),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 2.5),
                      ...data.hourlyList.map((h) {
                        final ratio = maxHourlySales > 0 ? (h.grossSales / maxHourlySales).clamp(0.0, 1.0) : 0.0;
                        final isPeak = h.grossSales == maxHourlySales && h.grossSales > 0;
                        final fillFlex = (ratio * 100).round();
                        final emptyFlex = 100 - fillFlex;

                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
                          child: pw.Row(
                            children: [
                              pw.SizedBox(
                                width: 68,
                                child: pw.Text(
                                  '${h.servicePeriod} (${h.timeWindow.split(" - ")[0].trim()})',
                                  maxLines: 1,
                                  style: pw.TextStyle(
                                    fontSize: 5.2,
                                    color: isPeak ? const PdfColor.fromInt(0xFFDC2626) : PdfColors.grey800,
                                    fontWeight: isPeak ? pw.FontWeight.bold : pw.FontWeight.normal,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Container(
                                  height: 5.5,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor.fromInt(0xFFE2E8F0),
                                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                                  ),
                                  child: pw.Row(
                                    children: [
                                      if (fillFlex > 0)
                                        pw.Expanded(
                                          flex: fillFlex,
                                          child: pw.Container(
                                            decoration: pw.BoxDecoration(
                                              color: isPeak ? const PdfColor.fromInt(0xFFDC2626) : primaryColor,
                                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                            ),
                                          ),
                                        ),
                                      if (emptyFlex > 0)
                                        pw.Expanded(
                                          flex: emptyFlex,
                                          child: pw.Container(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 4),
                              pw.SizedBox(
                                width: 70,
                                child: pw.Text(
                                  '${_formatPdfCount(h.ordersCount)} ord | ${_formatPdfMoney(h.grossSales)}',
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                    fontSize: 5.0,
                                    fontWeight: isPeak ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    color: isPeak ? const PdfColor.fromInt(0xFFDC2626) : PdfColors.grey800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        peakHour != null && peakHour.grossSales > 0
                            ? 'Peak service period: ${peakHour.servicePeriod} accounts for highest operational sales (${_formatPdfMoney(peakHour.grossSales)}).'
                            : 'Evenly distributed order volume across operating shifts.',
                        style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),

              // Right: Top 5 Best Selling Dishes visual bars
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '3. Top 5 Menu Items (Best Selling Dishes):',
                            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.Text(
                            'Top 5 by Revenue',
                            style: const pw.TextStyle(fontSize: 5.0, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2.5),
                      if (topDishes.isEmpty)
                        pw.Text('No menu item sales recorded.', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.grey600))
                      else
                        ...topDishes.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final d = entry.value;
                          final ratio = maxDishSales > 0 ? (d.revenue / maxDishSales).clamp(0.0, 1.0) : 0.0;
                          final fillFlex = (ratio * 100).round();
                          final emptyFlex = 100 - fillFlex;

                          final rankColor = idx == 0
                              ? goldColor
                              : (idx == 1
                                  ? const PdfColor.fromInt(0xFF94A3B8)
                                  : (idx == 2
                                      ? const PdfColor.fromInt(0xFFB45309)
                                      : const PdfColor.fromInt(0xFF64748B)));

                          return pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 0.9),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 8,
                                  height: 8,
                                  decoration: pw.BoxDecoration(
                                    color: rankColor,
                                    shape: pw.BoxShape.circle,
                                  ),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text(
                                    '${idx + 1}',
                                    style: pw.TextStyle(color: PdfColors.white, fontSize: 4.8, fontWeight: pw.FontWeight.bold),
                                  ),
                                ),
                                pw.SizedBox(width: 3),
                                pw.SizedBox(
                                  width: 65,
                                  child: pw.Text(
                                    d.name,
                                    maxLines: 1,
                                    style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Container(
                                    height: 5.5,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColor.fromInt(0xFFE2E8F0),
                                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                                    ),
                                    child: pw.Row(
                                      children: [
                                        if (fillFlex > 0)
                                          pw.Expanded(
                                            flex: fillFlex,
                                            child: pw.Container(
                                              decoration: const pw.BoxDecoration(
                                                color: PdfColor.fromInt(0xFF059669),
                                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                                              ),
                                            ),
                                          ),
                                        if (emptyFlex > 0)
                                          pw.Expanded(
                                            flex: emptyFlex,
                                            child: pw.Container(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.SizedBox(
                                  width: 70,
                                  child: pw.Text(
                                    '${_formatPdfCount(d.quantity)}x | ${_formatPdfMoney(d.revenue)}',
                                    textAlign: pw.TextAlign.right,
                                    style: const pw.TextStyle(fontSize: 5.0, color: PdfColors.grey800),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Total menu servings sold in this period: ${_formatPdfCount(data.totalQuantitySold)} servings.',
                        style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  pw.Widget _buildPdfLegendItem(String title, PdfColor color, String subtitle) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 7,
          height: 7,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
          ),
        ),
        pw.SizedBox(width: 3),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold)),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfInsightBullet(String title, String content, PdfColor titleColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold, color: titleColor)),
        pw.SizedBox(height: 1),
        pw.Text(content, style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.grey800)),
      ],
    );
  }

  pw.Widget _buildPdfExecutiveExplanation(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor borderColor,
  ) {
    final totalRev = data.grossRevenue;
    final totalOrders = data.totalOrders;
    final aov = data.avgOrderValue;

    String topChannelName = 'Walk-in / Dine-in';
    double topChannelRev = data.walkInRevenue;
    if (data.advanceRevenue > topChannelRev) {
      topChannelName = 'Advance Orders';
      topChannelRev = data.advanceRevenue;
    }
    if (data.reservationRevenue > topChannelRev) {
      topChannelName = 'Event Catering';
      topChannelRev = data.reservationRevenue;
    }

    _ReportHourlyBucketRecord? peakHour;
    for (final h in data.hourlyList) {
      if (peakHour == null || h.grossSales > peakHour.grossSales) {
        peakHour = h;
      }
    }

    final bestDish = data.bestSellers.isNotEmpty ? data.bestSellers.first : null;
    final slowDish = data.lowSellers.isNotEmpty ? data.lowSellers.first : null;

    final salesSummaryText = 'During the audit period (${data.dateRangeStr}), the restaurant achieved gross sales of ${_formatPdfMoney(totalRev)} across ${_formatPdfCount(totalOrders)} successfully completed transactions. The average order value (AOV) was ${_formatPdfMoney(aov)}, demonstrating healthy customer spending.';

    final channelText = 'The primary revenue driver during this period was $topChannelName amounting to ${_formatPdfMoney(topChannelRev)}. Channel contributions: Walk-in (${_formatPdfMoney(data.walkInRevenue)}), Advance Orders (${_formatPdfMoney(data.advanceRevenue)}), and Event Catering (${_formatPdfMoney(data.reservationRevenue)}).';

    final peakHourText = (peakHour != null && peakHour.grossSales > 0)
        ? 'The highest customer volume occurred during ${peakHour.servicePeriod} (${peakHour.timeWindow}) with ${_formatPdfCount(peakHour.ordersCount)} orders generating ${_formatPdfMoney(peakHour.grossSales)}. Proactive staging of kitchen crew and food prep stations is advised prior to this peak window.'
        : 'Order traffic remained steady and evenly distributed throughout operating hours.';

    final menuText = (bestDish != null)
        ? 'The top-selling dish was "${bestDish.name}" with ${_formatPdfCount(bestDish.quantity)} servings sold (${_formatPdfMoney(bestDish.revenue)}). ${slowDish != null && slowDish.name != bestDish.name ? 'Conversely, "${slowDish.name}" recorded the lowest sales volume (${_formatPdfCount(slowDish.quantity)} orders) and is recommended for combo meal bundling or promotional spotlighting.' : ''}'
        : 'Sales distribution is currently balanced across menu items.';

    final recommendations = [
      'Peak Hour Staging: Ensure kitchen stations and pre-cooked food items are fully prepared prior to lunch and dinner rush hours to avoid service bottlenecks.',
      'Inventory Threshold: ${data.lowStockItems > 0 ? 'There are ${data.lowStockItems} ingredients or items below minimum safety stock; initiate replenishment immediately.' : 'All kitchen inventory and ingredients remain within safe operational thresholds.'}',
      'Revenue Optimization: Promote advance pre-orders and weekday catering packages to sustain consistent daily sales volume.',
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.TableBorder.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EXECUTIVE SUMMARY & OPERATIONAL AUDIT (EXECUTIVE INSIGHTS)',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.Text(
                'Official Executive Review',
                style: const pw.TextStyle(fontSize: 6.2, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          _buildPdfInsightBullet('1. Overall Sales Performance:', salesSummaryText, primaryColor),
          pw.SizedBox(height: 3),
          _buildPdfInsightBullet('2. Sales Channel Breakdown:', channelText, primaryColor),
          pw.SizedBox(height: 3),
          _buildPdfInsightBullet('3. Peak Service Hours & Demand:', peakHourText, primaryColor),
          pw.SizedBox(height: 3),
          _buildPdfInsightBullet('4. Menu Movement & Kitchen Production:', menuText, primaryColor),
          pw.SizedBox(height: 3),

          pw.Text('5. Strategic Recommendations & Action Items:',
              style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 2),
          ...recommendations.map((rec) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 6, bottom: 1.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 2, right: 3.5),
                  width: 2.2,
                  height: 2.2,
                  decoration: pw.BoxDecoration(
                    color: goldColor,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(rec, style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.grey800)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<pw.Widget> _buildPdfDailyTableWidgets(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor headerBg,
    PdfColor alternateRowColor,
    PdfColor borderColor,
  ) {
    // Show ALL operating days in the PDF
    final double avgDailySales = data.dailyList.isNotEmpty
        ? data.dailyList.fold<double>(0.0, (sum, d) => sum + d.grossSales) / data.dailyList.length
        : 0.0;

    final rowsData = data.dailyList.map((day) {
      final dayAov = day.ordersCount > 0 ? day.grossSales / day.ordersCount : 0.0;
      String benchmark = 'Steady Sales';
      if (data.dailyList.length > 1) {
        if (day.grossSales >= avgDailySales * 1.20) {
          benchmark = 'High Sales';
        } else if (day.grossSales <= avgDailySales * 0.80) {
          benchmark = 'Low Sales';
        }
      } else {
        benchmark = 'Daily Operations';
      }

      return [
        day.dateStr,
        day.dayOfWeek,
        _formatPdfCount(day.ordersCount),
        _formatPdfCount(day.itemsSold),
        _formatPdfMoney(day.grossSales),
        _formatPdfMoney(dayAov),
        benchmark,
      ];
    }).toList();

    final totalSales = data.dailyList.fold<double>(0.0, (s, d) => s + d.grossSales);
    final totalOrders = data.dailyList.fold<int>(0, (s, d) => s + d.ordersCount);
    final totalItems = data.dailyList.fold<int>(0, (s, d) => s + d.itemsSold);
    final overallAov = totalOrders > 0 ? totalSales / totalOrders : 0.0;

    rowsData.add([
      'Period Total',
      '${_formatPdfCount(data.dailyList.length)} Operating Days',
      _formatPdfCount(totalOrders),
      _formatPdfCount(totalItems),
      _formatPdfMoney(totalSales),
      _formatPdfMoney(overallAov),
      '-',
    ]);

    return [
      pw.Text('1. DAILY SALES BREAKDOWN (${data.dailyList.length} Operating Days)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Day', 'Orders', 'Dishes Sold', 'Sales (PHP)', 'Average Spend', 'Daily Activity'],
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerLeft,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      ),
    ];
  }

  List<pw.Widget> _buildPdfHourlyTableWidgets(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor headerBg,
    PdfColor alternateRowColor,
    PdfColor borderColor,
  ) {
    final rowsData = data.hourlyList.map((b) {
      final share = data.grossRevenue > 0 ? (b.grossSales / data.grossRevenue) * 100 : 0.0;
      final orders = b.ordersCount;
      String traffic = 'Quiet / Off-Peak';
      if (orders >= 10 || (orders >= 4 && share >= 25.0)) {
        traffic = 'Peak Rush Hour';
      } else if (orders >= 5 || (orders >= 2 && share >= 15.0)) {
        traffic = 'Moderate Service';
      }
      return [
        b.servicePeriod,
        b.timeWindow,
        _formatPdfCount(b.ordersCount),
        _formatPdfCount(b.itemsSold),
        _formatPdfMoney(b.grossSales),
        traffic,
      ];
    }).toList();

    return [
      pw.Text('2. MEAL RUSH HOURS & PEAK SERVICE TIMES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        headers: ['Meal Service Period', 'Time Window', 'Orders', 'Dishes', 'Sales (PHP)', 'Traffic Level'],
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerLeft,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      ),
    ];
  }

  List<pw.Widget> _buildPdfBestSellersTableWidgets(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor headerBg,
    PdfColor alternateRowColor,
    PdfColor borderColor,
  ) {
    int rank = 1;
    final rowsData = data.bestSellers.map((item) {
      return [
        (rank++).toString(),
        item.name,
        item.category,
        _formatPdfCount(item.quantity),
        _formatPdfMoney(item.revenue),
      ];
    }).toList();

    if (rowsData.isEmpty) {
      rowsData.add(['-', 'No items recorded with sales in this period', '-', '0', 'PHP 0.00']);
    }

    return [
      pw.Text('3. TOP SELLING DISHES & BEST SELLERS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      pw.Text('Top dishes ranked dynamically by units sold in this period (${data.reportPeriodLabel})', style: pw.TextStyle(fontSize: 6.2, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        headers: ['Rank', 'Dish / Menu Item', 'Category', 'Units Sold', 'Total Sales (PHP)'],
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      ),
    ];
  }

  List<pw.Widget> _buildPdfLowSellersTableWidgets(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor headerBg,
    PdfColor alternateRowColor,
    PdfColor borderColor,
  ) {
    int rank = 1;
    // Exclude items that also appear in bestSellers to avoid duplication in the slow-movers list
    final bestSellerNames = data.bestSellers.map((b) => b.name).toSet();
    final trueSlowMovers = data.lowSellers.where((item) => !bestSellerNames.contains(item.name) || item.quantity == 0).toList();
    final rowsData = trueSlowMovers.map((item) {
      String rec = 'Steady Demand';
      if (item.quantity == 0) {
        rec = 'Zero Orders - Consider Promo / Review';
      } else if (item.quantity <= 2) {
        rec = 'Low Volume - Feature in Combos';
      }
      return [
        (rank++).toString(),
        item.name,
        item.category,
        _formatPdfCount(item.quantity),
        _formatPdfMoney(item.revenue),
        rec,
      ];
    }).toList();

    if (rowsData.isEmpty) {
      rowsData.add(['-', 'No slow moving items detected', '-', '0', 'PHP 0.00', 'N/A']);
    }

    return [
      pw.Text('4. SLOW-MOVING DISHES (FOR MANAGER REVIEW)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      pw.Text('Dishes with zero or lowest orders in this period (Bottom sample; full menu in CSV export)', style: pw.TextStyle(fontSize: 6.2, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        headers: ['Rank', 'Dish / Menu Item', 'Category', 'Units Sold', 'Total Sales (PHP)', 'Manager Recommendation'],
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerLeft,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      ),
    ];
  }

  List<pw.Widget> _buildPdfOrdersLogTableWidgets(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor headerBg,
    PdfColor alternateRowColor,
    PdfColor borderColor,
  ) {
    const int maxPdfRows = 60;
    final totalCount = data.transactions.length;
    final isCapped = totalCount > maxPdfRows;
    final displayedTransactions = isCapped ? data.transactions.take(maxPdfRows).toList() : data.transactions;

    if (data.isEventOnly) {
      final rowsData = displayedTransactions.map((t) {
        final date = (t['raw_date'] as DateTime).toLocal();
        final eventDateStr = (t['event_date']?.toString().isNotEmpty == true)
            ? '${t['event_date']} ${t['start_time'] ?? ''}'.trim()
            : DateFormat('MMM d, hh:mm a').format(date);
        final ref = t['id']?.toString() ?? '#N/A';
        final host = t['customer']?.toString() ?? 'Guest';
        final eventType = t['event_type']?.toString() ?? 'Banquet Event';
        final guests = '${t['number_of_guests'] ?? 0} pax';
        final depositAmt = (t['deposit_amount'] as num?)?.toDouble() ?? 0.0;
        final depositStr = _formatPdfMoney(depositAmt);
        final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
        final totalAmt = (t['total_price'] as num?)?.toDouble() ?? ((t['raw_amount'] as num?)?.toDouble() ?? 0.0);
        final totalStr = isValidRev ? _formatPdfMoney(totalAmt) : 'PHP 0.00';
        final statusStr = isValidRev ? (t['status']?.toString() ?? 'Confirmed') : '${t['status'] ?? 'Void'} (Excluded)';

        return [
          eventDateStr,
          ref,
          host,
          eventType,
          guests,
          depositStr,
          totalStr,
          statusStr,
        ];
      }).toList();

      return [
        pw.Text('5. EVENT CATERING BOOKINGS AUDIT LOG ($totalCount records)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        pw.SizedBox(height: 3),
        pw.TableHelper.fromTextArray(
          headers: ['Event Date & Time', 'Booking Ref', 'Host / Client', 'Event Type', 'Guests', 'Deposit (PHP)', 'Total (PHP)', 'Status'],
          data: rowsData,
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
          headerDecoration: pw.BoxDecoration(color: primaryColor),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
          cellStyle: const pw.TextStyle(fontSize: 6.5),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerLeft,
          },
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        ),
        if (isCapped) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Text(
              '* Paunawa: Ipinapakita ang pinakabagong $maxPdfRows tala sa PDF report na ito para sa mabilis at maayos na format. Para sa buong database audit ($totalCount bookings), i-export gamit ang Excel format.',
              style: pw.TextStyle(fontSize: 6.5, color: const PdfColor.fromInt(0xFF475569)),
            ),
          ),
        ],
      ];
    } else if (data.isAdvanceOnly) {
      final rowsData = displayedTransactions.map((t) {
        final date = (t['raw_date'] as DateTime).toLocal();
        final fulfillDateStr = (t['order_date']?.toString().isNotEmpty == true)
            ? '${t['order_date']} ${t['order_time'] ?? ''}'.trim()
            : DateFormat('MMM d, hh:mm a').format(date);
        final ref = t['id']?.toString() ?? '#N/A';
        final customer = t['customer']?.toString() ?? 'Guest';
        final orderType = t['order_type']?.toString() ?? 'Pickup';
        final dishesSummary = t['_itemsSummary']?.toString() ?? 'Pre-Order Items';
        final payment = t['payment_method']?.toString() ?? 'Online';
        final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
        final revAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
        final amountStr = isValidRev ? _formatPdfMoney(revAmt) : 'PHP 0.00';
        final statusStr = isValidRev ? (t['status']?.toString() ?? 'Completed') : '${t['status'] ?? 'Void'} (Excluded)';

        return [
          fulfillDateStr,
          ref,
          customer,
          orderType,
          dishesSummary,
          payment,
          amountStr,
          statusStr,
        ];
      }).toList();

      return [
        pw.Text('5. ADVANCE PRE-ORDERS FULFILLMENT LOG ($totalCount records)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        pw.SizedBox(height: 3),
        pw.TableHelper.fromTextArray(
          headers: ['Fulfill Date', 'Order Ref', 'Customer', 'Type', 'Dishes Summary', 'Payment', 'Total (PHP)', 'Status'],
          data: rowsData,
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
          headerDecoration: pw.BoxDecoration(color: primaryColor),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
          cellStyle: const pw.TextStyle(fontSize: 6.5),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerLeft,
            5: pw.Alignment.centerLeft,
            6: pw.Alignment.centerRight,
            7: pw.Alignment.centerLeft,
          },
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        ),
        if (isCapped) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Text(
              '* Note: Displaying the most recent $maxPdfRows records in this PDF report for layout efficiency. For a complete database audit of all $totalCount orders, export using the Excel format.',
              style: pw.TextStyle(fontSize: 6.5, color: const PdfColor.fromInt(0xFF475569)),
            ),
          ),
        ],
      ];
    }

    // Default: Show ALL / regular transactions in the PDF
    final rowsData = displayedTransactions.map((t) {
      final date = (t['raw_date'] as DateTime).toLocal();
      final dateFormatted = DateFormat('MMM d, hh:mm a').format(date);
      final ref = t['id']?.toString() ?? '#N/A';
      final isPosTakeout = (t['is_pos_takeout'] as bool?) ?? false;
      final type = isPosTakeout
          ? 'Take-out'
          : (t['type'] == 'Regular'
              ? 'Dine-in / Walk-in'
              : (t['type'] == 'Advance' ? 'Pre-Order' : 'Catering Event'));
      final customer = t['customer']?.toString() ?? 'Guest';
      final payment = t['payment_method']?.toString() ?? 'Cash';
      final itemsCount = (t['_itemsCount'] as int?) ?? 1;
      final isValidRev = (t['is_valid_revenue'] as bool?) ?? false;
      final revAmt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
      final amountStr = isValidRev ? _formatPdfMoney(revAmt) : 'PHP 0.00';
      final staff = t['processed_by']?.toString() ?? 'Staff';
      final statusStr = isValidRev ? (t['status']?.toString() ?? 'Completed') : '${t['status'] ?? 'Void'} (Excluded)';

      return [
        dateFormatted,
        ref,
        type,
        customer,
        payment,
        itemsCount.toString(),
        amountStr,
        staff,
        statusStr,
      ];
    }).toList();

    return [
      pw.Text('5. COMPLETE SALES ORDERS & RECEIPT LOG ($totalCount records)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        headers: ['Date & Time', 'Receipt Ref', 'Order Type', 'Customer', 'Payment', 'Dishes', 'Total Paid', 'Staff', 'Status'],
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: alternateRowColor),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerLeft,
          4: pw.Alignment.centerLeft,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
          7: pw.Alignment.centerLeft,
          8: pw.Alignment.centerLeft,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      ),
      if (isCapped) ...[
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF1F5F9),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: borderColor, width: 0.5),
          ),
          child: pw.Text(
            '* Note: Displaying the most recent $maxPdfRows records in this PDF report for layout efficiency. For a complete database audit of all $totalCount transactions, export using the Excel format.',
            style: pw.TextStyle(fontSize: 6.5, color: const PdfColor.fromInt(0xFF475569)),
          ),
        ),
      ],
    ];
  }

  pw.Widget _buildPdfSignOffBlock(_ProcessedReportData data, PdfColor primaryColor, PdfColor borderColor) {
    final staffDesignation = data.isEventOnly
        ? 'Catering & Events Coordinator | Yang Chow Pagsanjan'
        : (data.isAdvanceOnly
            ? 'Orders & Dispatch Officer | Yang Chow Pagsanjan'
            : 'POS / Admin Staff | Yang Chow Pagsanjan');

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.TableBorder.all(color: borderColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: const PdfColor.fromInt(0xFFFAFAFA),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Report Prepared & Generated By:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 14),
              pw.Container(width: 170, height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Text(data.generatedBy, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              pw.Text(staffDesignation, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reviewed & Certified By:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 14),
              pw.Container(width: 170, height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Text('Store Manager / Owner', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date Certified: ____________________', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
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
                                  Text(AppConstants.appName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText), overflow: TextOverflow.ellipsis),
                                  Text('Sales Transaction Voucher', style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Excluded icon as requested
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
                      if ((transaction['type'] == 'Advance' || transaction['type'] == 'Reservation') && transaction['selected_menu_items'] != null && transaction['selected_menu_items'] is Map) {
                        final Map<String, dynamic> items = Map<String, dynamic>.from(transaction['selected_menu_items'] as Map);
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
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          Flexible(
            child: Container(
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
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.adminSidebarBackground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
                  overflow: TextOverflow.ellipsis,
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
                        final bool isInitialLoading = (orderSnapshot.connectionState == ConnectionState.waiting && orderSnapshot.data == null) &&
                            (advanceOrderSnapshot.connectionState == ConnectionState.waiting && advanceOrderSnapshot.data == null) &&
                            (reservationsSnapshot.connectionState == ConnectionState.waiting && reservationsSnapshot.data == null);

                        if (isInitialLoading) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppTheme.adminPrimaryAccent),
                                SizedBox(height: 16),
                                Text(
                                  'Retrieving real-time sales data...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.adminSecondaryText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final allOrders = orderSnapshot.data ?? [];
                        final allAdvanceOrders = advanceOrderSnapshot.data ?? [];
                        final allReservations = reservationsSnapshot.data ?? [];
                        final allInventory = invSnapshot.data ?? [];

                        final metrics = _processMetrics(allOrders, allAdvanceOrders, allReservations, channelFilter: activeStreams);
                        final chartValues = _processChartData(allOrders, allAdvanceOrders, allReservations);

                        final lowStockCount = allInventory.where((item) {
                          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                          return qty < 10;
                        }).length;
                        metrics['lowStock'] = lowStockCount;

                        // Calculate Advance Order Performance Metrics (Scoped to Selected Period)
                        final periodAdvanceOrders = allAdvanceOrders.where((o) {
                          final rawDate = _parseDateWithTime(o['order_date'], o['order_time'], o['created_at']);
                          return _isDateInSelectedPeriod(rawDate);
                        }).toList();

                        final double advanceOrderRevenueTotal = (metrics['advanceRevenue'] as num?)?.toDouble() ?? 0.0;
                        final int completedAdvanceOrdersCount = (metrics['advanceOrders'] as num?)?.toInt() ?? 0;
                        final double advanceCancellationRate = (metrics['advanceCancellationRate'] as num?)?.toDouble() ?? 0.0;

                        final Map<String, int> popularAdvanceItems = {};
                        for (var o in periodAdvanceOrders) {
                          if (o['status'] == 'done' || o['status'] == 'completed' || o['status'] == 'ready') {
                            final rawItems = o['selected_menu_items'];
                            if (rawItems is Map) {
                              rawItems.forEach((name, qty) {
                                final count = (qty as num?)?.toInt() ?? 0;
                                popularAdvanceItems[name.toString()] = (popularAdvanceItems[name.toString()] ?? 0) + count;
                              });
                            }
                          }
                        }

                        // Calculate Event Reservation Performance Metrics (Scoped to Selected Period)
                        final periodReservations = allReservations.where((r) {
                          final rawDate = _parseDateWithTime(r['event_date'], r['start_time'], r['created_at']);
                          return _isDateInSelectedPeriod(rawDate);
                        }).toList();

                        final paidEventReservations = periodReservations.where((r) {
                          final status = (r['status'] ?? '').toString().toLowerCase();
                          final pStatus = (r['payment_status'] ?? '').toString().toLowerCase();
                          if (status == 'cancelled' || status == 'voided' || status == 'refunded' || pStatus == 'refunded' || pStatus == 'cancelled') return false;
                          return pStatus == 'paid' || pStatus == 'fully_paid' || pStatus == 'deposit_paid';
                        }).toList();

                        final double eventReservationRevenueTotal = paidEventReservations.fold(0.0, (sum, r) {
                          final pStatus = r['payment_status']?.toString() ?? '';
                          if (pStatus == 'deposit_paid') {
                            return sum + ((r['deposit_amount'] as num?)?.toDouble() ?? ((r['total_price'] as num?)?.toDouble() ?? 0.0) / 2);
                          }
                          return sum + ((r['total_price'] as num?)?.toDouble() ?? 0.0);
                        });

                        final int completedEventReservationsCount = periodReservations
                            .where((r) => r['status'] == 'completed' || r['status'] == 'confirmed')
                            .length;

                        final int cancelledEventReservationsCount = periodReservations
                            .where((r) {
                              final status = (r['status'] ?? '').toString().toLowerCase();
                              final pStatus = (r['payment_status'] ?? '').toString().toLowerCase();
                              return status == 'cancelled' || status == 'voided' || status == 'refunded' || pStatus == 'refunded' || pStatus == 'cancelled';
                            })
                            .length;

                        final double eventCancellationRate = periodReservations.isNotEmpty
                            ? (cancelledEventReservationsCount / periodReservations.length) * 100
                            : 0.0;

                        final Map<String, int> popularEventTypes = {};
                        for (var r in periodReservations) {
                          final eventType = r['event_type']?.toString() ?? 'Special Event';
                          popularEventTypes[eventType] = (popularEventTypes[eventType] ?? 0) + 1;
                        }

                        metrics['advanceCancellationRate'] = advanceCancellationRate;
                        metrics['eventCancellationRate'] = eventCancellationRate;

                        // Compile All Transactions for the Table
                        List<Map<String, dynamic>> combinedTransactions = [];

                        // 1. Regular & POS Take-out Orders
                        for (var o in allOrders) {
                          final date = DateTime.tryParse(o['created_at'] ?? '');
                          if (date == null) continue;
                          final name = o['customer_name']?.toString() ?? 'Guest';
                          final dbStatus = o['kitchen_status']?.toString() ?? 'Done';
                          final status = (o['status']?.toString() ?? dbStatus);
                          final stLower = status.toLowerCase();
                          final pStatus = (o['payment_status']?.toString() ?? '').toLowerCase();
                          final isCancelled = stLower == 'cancelled' || stLower == 'voided' || pStatus == 'refunded' || pStatus == 'cancelled';
                          final isValidRevenue = !isCancelled;
                          final rawAmt = (o['total_amount'] as num?)?.toDouble() ?? (o['total_price'] as num?)?.toDouble() ?? 0.0;
                          final revAmt = isValidRevenue ? rawAmt : 0.0;
                          final rawTxnId = o['transaction_id'];
                          final rawDbId = o['id']?.toString() ?? '';
                          final isTakeout = _isOrderTakeout(o);
                          const streamType = 'Regular';
                          final shortRef = _formatTransactionRef(rawTxnId, rawDbId, 'Regular');
                          final processedBy = _resolveProcessedBy(o, streamType);
                          final paymentMethod = o['payment_method']?.toString() ?? 'Cash';
                          
                          combinedTransactions.add({
                            'db_id': rawDbId,
                            'db_source': 'orders',
                            'is_pos_takeout': isTakeout,
                            'raw_id': (rawTxnId ?? rawDbId).toString(),
                            'id': shortRef,
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(date.toLocal()),
                            'full_date': DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()),
                            'raw_date': date,
                            'raw_amount': rawAmt,
                            'revenue_amount': revAmt,
                            'is_valid_revenue': isValidRevenue,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': dbStatus == 'Done' ? 'Completed' : (dbStatus.isEmpty ? 'Completed' : dbStatus),
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.regularOrderBlue,
                            'type': streamType,
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                            'payment_status': pStatus,
                            'order_type': isTakeout ? 'Take-out' : 'Dine-in',
                            'note': o['note'],
                            'table_number': o['table_number'],
                          });
                        }

                        // 2. Advance Orders
                        for (var adv in allAdvanceOrders) {
                          final date = _parseDateWithTime(adv['order_date'], adv['order_time'], adv['created_at']);
                          if (date == null) continue;
                          final name = adv['customer_name']?.toString() ?? 'Guest';
                          final status = adv['status']?.toString().toLowerCase() ?? 'pending';
                          final pStatus = (adv['payment_status']?.toString() ?? '').toLowerCase();
                          final isCancelled = status == 'cancelled' || pStatus == 'refunded' || pStatus == 'cancelled';
                          final isPaid = pStatus == 'paid' || pStatus == 'fully_paid';
                          final isValidRevenue = !isCancelled && (isPaid || status == 'completed' || status == 'done' || status == 'ready');
                          final rawAmt = (adv['total_price'] as num?)?.toDouble() ?? 0.0;
                          final revAmt = isValidRevenue ? rawAmt : 0.0;
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
                            'revenue_amount': revAmt,
                            'is_valid_revenue': isValidRevenue,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Pending',
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.advanceOrderGreen,
                            'type': 'Advance',
                            'selected_menu_items': adv['selected_menu_items'],
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                            'payment_status': pStatus,
                            'order_type': adv['order_type']?.toString() ?? 'Pickup',
                            'customer_phone': adv['customer_phone']?.toString() ?? adv['contact_number']?.toString() ?? '',
                            'order_date': adv['order_date']?.toString() ?? '',
                            'order_time': adv['order_time']?.toString() ?? '',
                            'special_instructions': adv['special_instructions']?.toString() ?? adv['notes']?.toString() ?? '',
                          });
                        }

                        // 3. Reservations
                        for (var res in allReservations) {
                          final date = _parseDateWithTime(res['event_date'], res['start_time'], res['created_at']);
                          if (date == null) continue;
                          final name = res['customer_name']?.toString() ?? 'Guest';
                          final status = res['status']?.toString().toLowerCase() ?? 'pending';
                          final pStatus = (res['payment_status']?.toString() ?? '').toLowerCase();
                          final isCancelled = status == 'cancelled' || pStatus == 'refunded' || pStatus == 'cancelled';
                          final isDeposit = pStatus == 'deposit_paid';
                          final isFullyPaid = pStatus == 'paid' || pStatus == 'fully_paid' || status == 'confirmed' || status == 'completed';
                          final isValidRevenue = !isCancelled && (isDeposit || isFullyPaid);
                          double rawAmt = 0.0;
                          if (isDeposit) {
                            rawAmt = (res['deposit_amount'] as num?)?.toDouble() ?? ((res['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
                          } else {
                            rawAmt = (res['total_price'] as num?)?.toDouble() ?? 0.0;
                          }
                          final revAmt = isValidRevenue ? rawAmt : 0.0;
                          final rawDbId = res['id']?.toString() ?? '';
                          final shortRef = _formatTransactionRef(res['transaction_id'], rawDbId, 'Reservation');
                          final processedBy = _resolveProcessedBy(res, 'Reservation');
                          final paymentMethod = res['payment_method']?.toString() ?? (isDeposit ? 'Deposit (GCash/Card)' : 'Full Payment');

                          combinedTransactions.add({
                            'db_id': rawDbId,
                            'raw_id': (res['transaction_id'] ?? rawDbId).toString(),
                            'id': shortRef,
                            'customer': name,
                            'date': DateFormat('MMM d, yyyy').format(date.toLocal()),
                            'full_date': DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()),
                            'raw_date': date,
                            'raw_amount': rawAmt,
                            'revenue_amount': revAmt,
                            'is_valid_revenue': isValidRevenue,
                            'amount': _currencyFormat.format(rawAmt),
                            'status': status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Pending',
                            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                            'color': AppTheme.reservationPurple,
                            'type': 'Reservation',
                            'selected_menu_items': res['selected_menu_items'],
                            'processed_by': processedBy,
                            'payment_method': paymentMethod,
                            'payment_status': pStatus,
                            'event_type': res['event_type']?.toString() ?? 'Banquet Event',
                            'event_date': res['event_date']?.toString() ?? '',
                            'start_time': res['start_time']?.toString() ?? '',
                            'end_time': res['end_time']?.toString() ?? '',
                            'number_of_guests': (res['number_of_guests'] as num?)?.toInt() ?? (res['guest_count'] as num?)?.toInt() ?? 0,
                            'table_number': res['table_number']?.toString() ?? res['location']?.toString() ?? '',
                            'customer_phone': res['contact_number']?.toString() ?? res['customer_phone']?.toString() ?? '',
                            'payment_option': res['payment_option']?.toString() ?? (isDeposit ? 'Deposit' : 'Full Payment'),
                            'deposit_amount': (res['deposit_amount'] as num?)?.toDouble() ?? (isDeposit ? rawAmt : 0.0),
                            'total_price': (res['total_price'] as num?)?.toDouble() ?? rawAmt,
                            'remaining_balance': (res['remaining_balance'] as num?)?.toDouble() ?? 0.0,
                            'special_instructions': res['special_instructions']?.toString() ?? res['notes']?.toString() ?? '',
                          });
                        }

                        // Filter transactions by active channel streams
                        combinedTransactions = combinedTransactions
                            .where((t) => activeStreams.contains(t['type'] as String? ?? ''))
                            .toList();

                        // Sort newest first
                        combinedTransactions.sort((a, b) => (b['raw_date'] as DateTime).compareTo(a['raw_date'] as DateTime));

                        final currentOpsKey = '${selectedPeriod}_${selectedYear}_${_getSubPeriodCacheKey()}_${activeStreams.join(',')}_${combinedTransactions.length}';
                        if (_operationalDataCacheKey != currentOpsKey && !_isLoadingOperationalData) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _operationalDataCacheKey != currentOpsKey) {
                              _loadOperationalData(combinedTransactions, metrics, currentOpsKey);
                            }
                          });
                        }

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

                                // Operational Intelligence: Meal Rush Hours & Menu Velocity (Top & Slow Moving)
                                _buildOperationalInsightsSection(isDesktop, combinedTransactions, metrics),
                                const SizedBox(height: AppTheme.xl),

                                // Payment Method Distribution Analytics: Tender Settlement across POS, Advance & Reservations
                                _buildPaymentDistributionSection(isDesktop, combinedTransactions, metrics),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _periodDropdownWidget(),
                      const SizedBox(width: 8),
                      _buildSubPeriodSelectors(),
                      if (selectedPeriod != 'Annually') const SizedBox(width: 8),
                      _yearDropdownWidget(),
                      const SizedBox(width: 8),
                      _exportDropdownWidget(transactions, metrics),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/admin/sales-forecast'),
                        icon: const Icon(Icons.auto_graph_rounded, size: 15, color: AppTheme.adminPrimaryAccent),
                        label: const Text('Forecasting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeaderTitleBlock()),
                _periodDropdownWidget(),
                const SizedBox(width: 8),
                _buildSubPeriodSelectors(),
                if (selectedPeriod != 'Annually') const SizedBox(width: 8),
                _yearDropdownWidget(),
                const SizedBox(width: 12),
                _exportDropdownWidget(transactions, metrics),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/admin/sales-forecast'),
                  icon: const Icon(Icons.auto_graph_rounded, size: 15, color: AppTheme.adminPrimaryAccent),
                  label: const Text('Sales Forecast', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cardBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
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
                    'Sales & Gross Report',
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
                style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText, height: 1.2),
                maxLines: 2,
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

  Widget _buildSubPeriodSelectors() {
    final year = int.tryParse(selectedYear) ?? DateTime.now().year;

    if (selectedPeriod == 'Daily') {
      final monthIdx = _getMonthIndex(selectedDailyMonth);
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      final dayItems = List.generate(daysInMonth, (i) => (i + 1).toString());

      if (int.tryParse(selectedDailyDay) == null || int.parse(selectedDailyDay) > daysInMonth) {
        selectedDailyDay = daysInMonth.toString();
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Daily Month Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                focusNode: _dailyMonthFocusNode,
                value: selectedDailyMonth,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
                dropdownColor: Colors.white,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
                items: _monthFilters.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) {
                  _dailyMonthFocusNode.unfocus();
                  if (v != null && mounted) setState(() => selectedDailyMonth = v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Daily Day Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                focusNode: _dailyDayFocusNode,
                value: selectedDailyDay,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
                dropdownColor: Colors.white,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
                items: dayItems.map((d) => DropdownMenuItem(value: d, child: Text('Day $d'))).toList(),
                onChanged: (v) {
                  _dailyDayFocusNode.unfocus();
                  if (v != null && mounted) setState(() => selectedDailyDay = v);
                },
              ),
            ),
          ),
        ],
      );
    } else if (selectedPeriod == 'Weekly') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weekly Month Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                focusNode: _weeklyMonthFocusNode,
                value: selectedWeeklyMonth,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
                dropdownColor: Colors.white,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
                items: _monthFilters.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) {
                  _weeklyMonthFocusNode.unfocus();
                  if (v != null && mounted) setState(() => selectedWeeklyMonth = v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Weekly Week Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                focusNode: _weeklyWeekFocusNode,
                value: selectedWeeklyWeek,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
                dropdownColor: Colors.white,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
                 items: _weekFilters.map((w) {
                   final rangeLabel = _getWeekDateRangeLabel(w);
                   return DropdownMenuItem<String>(
                     value: w,
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(w),
                         if (rangeLabel.isNotEmpty) ...[
                           const SizedBox(width: 6),
                           Text(
                             rangeLabel,
                             style: const TextStyle(
                               fontSize: 11,
                               fontWeight: FontWeight.w400,
                               color: AppTheme.adminSecondaryText,
                             ),
                           ),
                         ],
                       ],
                     ),
                   );
                 }).toList(),
                onChanged: (v) {
                  _weeklyWeekFocusNode.unfocus();
                  if (v != null && mounted) setState(() => selectedWeeklyWeek = v);
                },
              ),
            ),
          ),
        ],
      );
    } else if (selectedPeriod == 'Monthly') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.adminMainBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            focusNode: _monthlyMonthFocusNode,
            value: selectedMonthlyMonth,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.darkGrey),
            dropdownColor: Colors.white,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.darkGrey),
            items: _monthFilters.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              _monthlyMonthFocusNode.unfocus();
              if (v != null && mounted) setState(() => selectedMonthlyMonth = v);
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
              items: List.generate(
                    DateTime.now().year - 2023 + 1,
                    (i) => (2023 + i).toString(),
                  ).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

  String get _exportFileNameBase {
    String channelTag;
    if (activeStreams.length == 1) {
      if (activeStreams.contains('Reservation')) {
        channelTag = 'Catering';
      } else if (activeStreams.contains('Advance')) {
        channelTag = 'AdvanceOrders';
      } else {
        channelTag = 'WalkIn';
      }
    } else if (activeStreams.length == 3) {
      channelTag = 'SalesReport';
    } else {
      channelTag = activeStreams.join('_');
    }

    String subPeriodTag = '';
    if (selectedPeriod == 'Daily') {
      subPeriodTag = '_${selectedDailyMonth}_$selectedDailyDay';
    } else if (selectedPeriod == 'Weekly') {
      subPeriodTag = '_${selectedWeeklyMonth}_${selectedWeeklyWeek.replaceAll(' ', '')}';
    } else if (selectedPeriod == 'Monthly') {
      subPeriodTag = '_$selectedMonthlyMonth';
    }

    return 'YangChow_${channelTag}_${selectedYear}_$selectedPeriod$subPeriodTag';
  }

  Widget _exportDropdownWidget(List<Map<String, dynamic>> transactions, Map<String, dynamic> metrics) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return ElevatedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.file_download_outlined, size: 16, color: AppTheme.warmGold),
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Export', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.adminSidebarBackground,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            elevation: 0,
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.warmGold),
          onPressed: () => _exportToPDF(
            transactions,
            _exportFileNameBase,
            metrics: metrics,
            directDownload: true,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Download PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText)),
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.print_outlined, size: 16, color: AppTheme.adminPrimaryText),
          onPressed: () => _exportToPDF(
            transactions,
            _exportFileNameBase,
            metrics: metrics,
            directDownload: false,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Print PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText)),
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF15803D)),
          onPressed: () => _exportToExcel(
            transactions,
            _exportFileNameBase,
            metrics: metrics,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Export Excel (Lahat ng Benta)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
          ),
        ),
      ],
    );
  }

  // ── 2. Top Executive KPI Cards ────────────────────────────────────────────────
  Widget _buildExecutiveKpiCards(Map<String, dynamic> data, bool isDesktop) {
    final double revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
    final int orders = (data['orders'] as num?)?.toInt() ?? 0;
    final double avgOrder = (data['avgOrder'] as num?)?.toDouble() ?? 0.0;
    final int customers = (data['customers'] as num?)?.toInt() ?? 0;
    final int lowStock = (data['lowStock'] as num?)?.toInt() ?? 0;

    final bool isEventOnly = activeStreams.length == 1 && activeStreams.contains('Reservation');
    final bool isAdvanceOnly = activeStreams.length == 1 && activeStreams.contains('Advance');

    // Build a human-readable channel label for subtitles
    final channelNames = {
      'Regular': 'Walk-in',
      'Advance': 'Advance',
      'Reservation': 'Catering',
    };
    final selectedLabels = activeStreams.map((k) => channelNames[k] ?? k).toList();
    final channelSubtitle = selectedLabels.length == 3
        ? 'All channels'
        : selectedLabels.join(' + ');

    final String ordersCardTitle = isEventOnly
        ? 'Total Bookings'
        : (isAdvanceOnly ? 'Total Pre-Orders' : 'Total Orders');
    final String ordersCardUnit = isEventOnly ? 'Bookings' : 'Orders';
    final String ordersCardSubtitle = isEventOnly
        ? 'Confirmed catering events'
        : (isAdvanceOnly ? 'Takeout & advance orders' : '$channelSubtitle orders');
    final IconData ordersCardIcon = isEventOnly
        ? Icons.event_available_outlined
        : Icons.shopping_bag_outlined;

    final String aovCardTitle = isEventOnly
        ? 'Avg. Event Value'
        : (isAdvanceOnly ? 'Avg. Pre-Order Value' : 'Avg. Spend Per Order');
    final String aovCardSubtitle = isEventOnly
        ? 'Average spend per booking'
        : 'Avg. per $channelSubtitle order';

    final String customersCardTitle = isEventOnly
        ? 'Event Guests (Pax)'
        : (isAdvanceOnly ? 'Pre-Order Patrons' : 'Total Guests Served');
    final String customersCardUnit = isEventOnly ? 'Pax' : 'Guests';
    final String customersCardSubtitle = isEventOnly
        ? 'Total event attendees'
        : '$channelSubtitle headcount';

    final cards = [
      // 1. Featured Gross Revenue Card
      _buildFeaturedRevenueCard(revenue, channelSubtitle),
      // 2. Total Completed Orders / Bookings
      _buildStandardKpiCard(
        title: ordersCardTitle,
        value: orders.toString(),
        unit: ordersCardUnit,
        subtitle: ordersCardSubtitle,
        icon: ordersCardIcon,
        accentColor: AppTheme.infoBlue,
      ),
      // 3. Average Order / Booking Value
      _buildStandardKpiCard(
        title: aovCardTitle,
        value: _currencyFormat.format(avgOrder),
        unit: '',
        subtitle: aovCardSubtitle,
        icon: Icons.receipt_long_outlined,
        accentColor: AppTheme.adminPrimaryAccent,
      ),
      // 4. Unique Patrons / Event Clients
      _buildStandardKpiCard(
        title: customersCardTitle,
        value: customers.toString(),
        unit: customersCardUnit,
        subtitle: customersCardSubtitle,
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

  Widget _buildFeaturedRevenueCard(double revenue, String channelSubtitle) {
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
                          'GROSS SALES',
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
          Text(
            channelSubtitle == 'All channels' ? 'Total Sales from All Channels' : 'Sales: $channelSubtitle only',
            style: const TextStyle(
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

  String get _chartSubtitle {
    if (selectedPeriod == 'Daily') return '$selectedDailyMonth $selectedDailyDay, $selectedYear';
    if (selectedPeriod == 'Weekly') return '$selectedWeeklyWeek of $selectedWeeklyMonth $selectedYear';
    if (selectedPeriod == 'Monthly') return '$selectedMonthlyMonth $selectedYear';
    return 'Annual Sales $selectedYear';
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
                      'Gross Analytics & Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.adminPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aggregated turnover for $_chartSubtitle',
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
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidget = SfCartesianChart(
                plotAreaBorderWidth: 0,
              margin: EdgeInsets.zero,
              tooltipBehavior: TooltipBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                  final _SalesReportData item = data;
                  final double val = point.y ?? 0.0;
                  String tooltipPeriodLabel = item.label;
                  if (selectedPeriod == 'Monthly') {
                    tooltipPeriodLabel = '$selectedMonthlyMonth ${item.label}, $selectedYear';
                  } else if (selectedPeriod == 'Daily') {
                    tooltipPeriodLabel = '$selectedDailyMonth $selectedDailyDay • ${item.label}';
                  } else if (selectedPeriod == 'Weekly') {
                    tooltipPeriodLabel = '${item.label}, $selectedYear';
                  } else {
                    tooltipPeriodLabel = '${item.label} $selectedYear';
                  }
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
                          '$tooltipPeriodLabel • ${series.name ?? 'Revenue'}',
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
                labelStyle: const TextStyle(color: AppTheme.adminSecondaryText, fontSize: 10, fontWeight: FontWeight.w600),
                axisLine: const AxisLine(width: 1, color: AppTheme.cardBorder),
                labelRotation: selectedPeriod == 'Daily' ? -35 : 0,
                interval: (selectedPeriod == 'Monthly') ? 2 : 1,
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
                          animationDuration: 0,
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
                          animationDuration: 0,
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
                          animationDuration: 0,
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
                          animationDuration: 0,
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
                          animationDuration: 0,
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
                          animationDuration: 0,
                        ),
                    ],
              );
              
              return SizedBox(
                height: isDesktop ? 320 : 250,
                child: isDesktop
                    ? chartWidget
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: const EdgeInsets.only(right: 16),
                          width: 650,
                          child: chartWidget,
                        ),
                      ),
              );
            },
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
              GlobalMessenger.showWarning('Kailangan may kahit isang sales stream na naka-select.');
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

  // ── 3.5 Operational Intelligence (Meal Rush Hours & Menu Velocity) ─────────
  Widget _buildOperationalInsightsSection(
    bool isDesktop,
    List<Map<String, dynamic>> transactions,
    Map<String, dynamic> metrics,
  ) {
    final double totalRevenue = (metrics['revenue'] as num?)?.toDouble() ?? 0.0;
    final hourlyData = _operationalReportData?.hourlyList ?? _computeQuickHourlyStats(transactions);
    final bestSellers = _operationalReportData?.bestSellers ?? [];
    final lowSellers = _operationalReportData?.lowSellers ?? [];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: _buildMealRushHoursCard(hourlyData, totalRevenue),
          ),
          const SizedBox(width: AppTheme.xl),
          Expanded(
            flex: 6,
            child: _buildMenuPerformanceCard(bestSellers, lowSellers, totalRevenue),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMealRushHoursCard(hourlyData, totalRevenue),
          const SizedBox(height: AppTheme.xl),
          _buildMenuPerformanceCard(bestSellers, lowSellers, totalRevenue),
        ],
      );
    }
  }

  Widget _buildMealRushHoursCard(
    List<_ReportHourlyBucketRecord> hourlyData,
    double totalRevenue,
  ) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Identify busiest window
    _ReportHourlyBucketRecord? peakBucket;
    for (var b in hourlyData) {
      if (b.grossSales > 0 || b.ordersCount > 0) {
        if (peakBucket == null || b.grossSales > peakBucket.grossSales) {
          peakBucket = b;
        }
      }
    }

    final double peakShare = (peakBucket != null && totalRevenue > 0)
        ? (peakBucket.grossSales / totalRevenue) * 100
        : 0.0;

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meal Rush Hours & Peak Times',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                      ),
                      Text(
                        'Customer traffic & rush density ($selectedPeriod)',
                        style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      'Live Heatmap',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hourly Bucket Tiles
          ...hourlyData.map((bucket) {
            final share = totalRevenue > 0 ? (bucket.grossSales / totalRevenue) * 100 : 0.0;
            final orders = bucket.ordersCount;
            final isPeak = orders >= 10 || (orders >= 4 && share >= 25.0);
            final isModerate = !isPeak && (orders >= 5 || (orders >= 2 && share >= 15.0));

            Color badgeBg;
            Color badgeBorder;
            Color badgeText;
            String trafficLabel;
            IconData trafficIcon;
            Color progressColor;

            if (isPeak) {
              badgeBg = const Color(0xFFFEF2F2);
              badgeBorder = const Color(0xFFFECACA);
              badgeText = const Color(0xFFDC2626);
              trafficLabel = 'Peak Rush Hour';
              trafficIcon = Icons.local_fire_department_rounded;
              progressColor = const Color(0xFFEF4444);
            } else if (isModerate) {
              badgeBg = const Color(0xFFFFFBEB);
              badgeBorder = const Color(0xFFFDE68A);
              badgeText = const Color(0xFFD97706);
              trafficLabel = 'Moderate Service';
              trafficIcon = Icons.bolt_rounded;
              progressColor = const Color(0xFFF59E0B);
            } else {
              badgeBg = const Color(0xFFF8FAFC);
              badgeBorder = const Color(0xFFE2E8F0);
              badgeText = const Color(0xFF64748B);
              trafficLabel = 'Off-Peak / Quiet';
              trafficIcon = Icons.coffee_rounded;
              progressColor = const Color(0xFF94A3B8);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(10),
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
                            Icon(Icons.access_time_rounded, size: 14, color: isPeak ? const Color(0xFFDC2626) : AppTheme.adminSecondaryText),
                            const SizedBox(width: 6),
                            Text(
                              bucket.timeWindow,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.adminPrimaryText),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• ${bucket.servicePeriod}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.mediumGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trafficIcon, size: 11, color: badgeText),
                            const SizedBox(width: 3),
                            Text(
                              trafficLabel,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${bucket.ordersCount} orders • ${bucket.itemsSold} items',
                          style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currencyFormat.format(bucket.grossSales),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isPeak ? const Color(0xFFDC2626) : AppTheme.adminPrimaryText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${share.toStringAsFixed(1)}%)',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: totalRevenue > 0 ? (share / 100.0).clamp(0.0, 1.0) : 0.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Peak Rush Insight Box
          if (peakBucket != null && peakBucket.ordersCount >= 3) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Operational Tip: Primary rush occurs at ${peakBucket.timeWindow} (${peakBucket.ordersCount} orders, ${peakShare.toStringAsFixed(1)}% of sales). Ensure kitchen prep stations and servers are fully ready prior to this window.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (peakBucket != null && peakBucket.ordersCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.mediumGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mababa pa ang volume ng orders (${peakBucket.ordersCount} order pa lang) para magkaroon ng Peak Rush Hour.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
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

  Widget _buildMenuPerformanceCard(
    List<_ReportItemSalesRecord> bestSellers,
    List<_ReportItemSalesRecord> lowSellers,
    double totalRevenue,
  ) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Filter true slow movers excluding best seller overlap
    final bestSellerNames = bestSellers.map((b) => b.name).toSet();
    final trueSlowMovers = lowSellers
        .where((item) => !bestSellerNames.contains(item.name) || item.quantity == 0)
        .toList();

    final isBest = _menuRankingFilter == 'best';
    final targetList = isBest ? bestSellers : trueSlowMovers;
    final displayItems = _showAllOperationalItems
        ? targetList.take(15).toList()
        : targetList.take(5).toList();

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
          // Responsive Header with Tab Toggle
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final titleWidget = Row(
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: isNarrow ? 1 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Menu Item Velocity',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                        ),
                        Text(
                          isBest ? 'Top selling menu items & dishes' : 'Slow-moving dishes for manager review',
                          style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final toggleWidget = Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Expanded(
                      flex: isNarrow ? 1 : 0,
                      child: InkWell(
                        onTap: () => setState(() => _menuRankingFilter = 'best'),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isBest ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isBest
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, size: 12, color: isBest ? const Color(0xFFD97706) : AppTheme.mediumGrey),
                              const SizedBox(width: 3),
                              Text(
                                'Best Sellers',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isBest ? FontWeight.bold : FontWeight.w500,
                                  color: isBest ? AppTheme.adminPrimaryText : AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: isNarrow ? 1 : 0,
                      child: InkWell(
                        onTap: () => setState(() => _menuRankingFilter = 'slow'),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !isBest ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: !isBest
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.trending_down_rounded, size: 12, color: !isBest ? const Color(0xFFDC2626) : AppTheme.mediumGrey),
                              const SizedBox(width: 3),
                              Text(
                                'Slow-Movers',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: !isBest ? FontWeight.bold : FontWeight.w500,
                                  color: !isBest ? AppTheme.adminPrimaryText : AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    toggleWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleWidget,
                  toggleWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Loading state
          if (_isLoadingOperationalData && _operationalReportData == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    SizedBox(height: 12),
                    Text(
                      'Sinusuri ang benta ng bawat putahe...',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey),
                    ),
                  ],
                ),
              ),
            )
          else if (targetList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBest ? Icons.inventory_2_outlined : Icons.check_circle_outline_rounded,
                      size: 32,
                      color: AppTheme.mediumGrey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBest
                          ? 'Walang naitalang dish sales para sa napiling period.'
                          : 'Walang slow-moving items na na-detect sa napiling period.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // List of items
            ...displayItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final share = totalRevenue > 0 ? (item.revenue / totalRevenue) * 100 : 0.0;

              // Rank decoration for Best Sellers
              Color rankBg;
              Color rankBorder;
              Color rankText;
              String rankDisplay = '#${idx + 1}';

              if (isBest) {
                if (idx == 0) {
                  rankBg = const Color(0xFFFEF3C7);
                  rankBorder = const Color(0xFFF59E0B);
                  rankText = const Color(0xFFB45309);
                  rankDisplay = '🥇 #1';
                } else if (idx == 1) {
                  rankBg = const Color(0xFFF1F5F9);
                  rankBorder = const Color(0xFF94A3B8);
                  rankText = const Color(0xFF475569);
                  rankDisplay = '🥈 #2';
                } else if (idx == 2) {
                  rankBg = const Color(0xFFFFEDD5);
                  rankBorder = const Color(0xFFFB923C);
                  rankText = const Color(0xFFC2410C);
                  rankDisplay = '🥉 #3';
                } else {
                  rankBg = const Color(0xFFF8FAFC);
                  rankBorder = const Color(0xFFE2E8F0);
                  rankText = const Color(0xFF64748B);
                }
              } else {
                // Slow movers rank
                rankBg = const Color(0xFFFEF2F2);
                rankBorder = const Color(0xFFFECACA);
                rankText = const Color(0xFFDC2626);
                rankDisplay = '⚠️ #${idx + 1}';
              }

              // Recommendation for slow movers
              String recommendation = 'Steady Demand';
              if (item.quantity == 0) {
                recommendation = 'Zero orders • Consider Bundle Promo';
              } else if (item.quantity <= 2) {
                recommendation = 'Low volume • Feature on Cashier Upsell';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFBFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: rankBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: rankBorder),
                      ),
                      child: Text(
                        rankDisplay,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rankText),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Dish Name & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.category,
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          if (isBest)
                            Text(
                              '${item.quantity} units sold • ${share.toStringAsFixed(1)}% of total sales',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText),
                            )
                          else
                            Text(
                              recommendation,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.quantity == 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quantity & Revenue
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(item.revenue),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isBest ? const Color(0xFF059669) : AppTheme.adminPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isBest
                                ? const Color(0xFFD1FAE5)
                                : (item.quantity == 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.quantity} sold',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isBest
                                  ? const Color(0xFF065F46)
                                  : (item.quantity == 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Actions Footer: Show More toggle & Complete Menu Audit Modal Button
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                if (targetList.length > 5)
                  TextButton.icon(
                    onPressed: () => setState(() => _showAllOperationalItems = !_showAllOperationalItems),
                    icon: Icon(
                      _showAllOperationalItems ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: AppTheme.adminSecondaryText,
                    ),
                    label: Text(
                      _showAllOperationalItems ? 'Show Top 5 Only' : 'Show Top 15',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.adminSecondaryText),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: lowSellers.isEmpty
                      ? null
                      : () => _showCompleteMenuRankingModal(context, bestSellers, lowSellers, totalRevenue),
                  icon: const Icon(Icons.table_chart_rounded, size: 14, color: AppTheme.adminPrimaryAccent),
                  label: Text(
                    'View Full Menu Audit (${lowSellers.length} items)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cardBorder),
                    backgroundColor: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 3.6 Complete Menu Ranking & Audit Modal (Handles 100+ items) ───────────
  void _showCompleteMenuRankingModal(
    BuildContext context,
    List<_ReportItemSalesRecord> bestSellers,
    List<_ReportItemSalesRecord> lowSellers,
    double totalRevenue,
  ) {
    final bestSellerNames = bestSellers.map((b) => b.name).toSet();
    final trueSlowMovers = lowSellers
        .where((item) => !bestSellerNames.contains(item.name) || item.quantity == 0)
        .toList();

    // All catalog items ranked descending from highest to lowest seller
    final allRanked = List<_ReportItemSalesRecord>.from(lowSellers)
      ..sort((a, b) => b.quantity != a.quantity
          ? b.quantity.compareTo(a.quantity)
          : b.revenue.compareTo(a.revenue));

    // Dynamic unique categories from all items (excluding order channel tags)
    const nonFoodCategories = {
      'Dine-in / Walk-in',
      'Advance Pre-Order',
      'Event Catering',
      'Regular',
      'Advance',
      'Reservation',
      'Standard Walk-in Order',
      'Pre-Order Package',
      'Event Catering Package',
    };
    final Set<String> categoriesSet = {'All Categories'};
    for (var i in lowSellers) {
      final cat = i.category.trim();
      if (cat.isNotEmpty && !nonFoodCategories.contains(cat)) {
        categoriesSet.add(cat);
      }
    }
    final categoriesList = categoriesSet.toList()..sort();

    final int totalDishes = lowSellers.length;
    final int activeDishes = bestSellers.length;
    final int inactiveDishes = lowSellers.where((i) => i.quantity == 0).length;

    showDialog(
      context: context,
      builder: (ctx) {
        String activeTab = 'best'; // 'best', 'slow', 'all'
        String selectedCategory = 'All Categories';
        String searchQuery = '';
        int modalPage = 1;
        const int itemsPerPage = 8;
        final TextEditingController modalSearchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final screenSize = MediaQuery.of(dialogCtx).size;
            final isMobile = ResponsiveUtils.isMobile(dialogCtx);

            // 1. Pick base dataset by active tab
            List<_ReportItemSalesRecord> currentDataset;
            if (activeTab == 'best') {
              currentDataset = bestSellers;
            } else if (activeTab == 'slow') {
              currentDataset = trueSlowMovers;
            } else {
              currentDataset = allRanked;
            }

            // 2. Apply Category filter
            if (selectedCategory != 'All Categories') {
              currentDataset = currentDataset.where((i) => i.category == selectedCategory).toList();
            }

            // 3. Apply Search query filter
            if (searchQuery.trim().isNotEmpty) {
              final q = searchQuery.trim().toLowerCase();
              currentDataset = currentDataset.where((i) {
                return i.name.toLowerCase().contains(q) || i.category.toLowerCase().contains(q);
              }).toList();
            }

            // 4. Pagination
            final int totalFilteredCount = currentDataset.length;
            final int totalPages = (totalFilteredCount / itemsPerPage).ceil().clamp(1, 9999);
            if (modalPage > totalPages) modalPage = totalPages;
            if (modalPage < 1) modalPage = 1;

            final pageItems = currentDataset
                .skip((modalPage - 1) * itemsPerPage)
                .take(itemsPerPage)
                .toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 32,
                vertical: isMobile ? 16 : 28,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 820,
                  maxHeight: screenSize.height * 0.90,
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D9488), Color(0xFF047857)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Complete Menu Sales Ranking',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                ),
                                Text(
                                  'Dynamic dish catalog audit ($selectedPeriod $selectedYear)',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.mediumGrey),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick KPI Cards Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildModalSummaryPill('Total Menu Dishes', '$totalDishes', Icons.restaurant_rounded, AppTheme.adminPrimaryText),
                          Container(width: 1, height: 26, color: AppTheme.cardBorder),
                          _buildModalSummaryPill('Selling Dishes', '$activeDishes', Icons.check_circle_rounded, const Color(0xFF059669)),
                          Container(width: 1, height: 26, color: AppTheme.cardBorder),
                          _buildModalSummaryPill('Zero Sales / Inactive', '$inactiveDishes', Icons.warning_amber_rounded, const Color(0xFFDC2626)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Controls: Search, Category Filter, and Tabs
                    Row(
                      children: [
                        // Search Box
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: modalSearchCtrl,
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                                modalPage = 1;
                              });
                            },
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search dish name or category...',
                              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.mediumGrey),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        modalSearchCtrl.clear();
                                        setModalState(() {
                                          searchQuery = '';
                                          modalPage = 1;
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: const Color(0xFFFBFBFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Category Dropdown Filter
                        Expanded(
                          flex: 4,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBFBFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppTheme.mediumGrey),
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.adminPrimaryText, fontWeight: FontWeight.w600),
                                items: categoriesList.map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() {
                                      selectedCategory = v;
                                      modalPage = 1;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filter Tabs: Best Sellers | Slow Movers | All Ranked
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModalTabPill(
                            label: '⭐ Best Sellers (${bestSellers.length})',
                            isSelected: activeTab == 'best',
                            activeColor: const Color(0xFFD97706),
                            onTap: () => setModalState(() {
                              activeTab = 'best';
                              modalPage = 1;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _buildModalTabPill(
                            label: '⚠️ Slow-Movers (${trueSlowMovers.length})',
                            isSelected: activeTab == 'slow',
                            activeColor: const Color(0xFFDC2626),
                            onTap: () => setModalState(() {
                              activeTab = 'slow';
                              modalPage = 1;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _buildModalTabPill(
                            label: '📋 All Catalog Dishes (${allRanked.length})',
                            isSelected: activeTab == 'all',
                            activeColor: AppTheme.adminSidebarBackground,
                            onTap: () => setModalState(() {
                              activeTab = 'all';
                              modalPage = 1;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.cardBorder),

                    // Paginated Dishes List
                    Expanded(
                      child: pageItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.mediumGrey),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'Walang putaheng tumugma sa "$searchQuery"'
                                        : 'Walang items para sa napiling filter.',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: pageItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (ctx, index) {
                                final item = pageItems[index];
                                final globalRank = (allRanked.indexWhere((i) => i.name == item.name) + 1);
                                final share = totalRevenue > 0 ? (item.revenue / totalRevenue) * 100 : 0.0;

                                Color rankBg = const Color(0xFFF8FAFC);
                                Color rankBorder = const Color(0xFFE2E8F0);
                                Color rankText = const Color(0xFF64748B);

                                if (globalRank == 1) {
                                  rankBg = const Color(0xFFFEF3C7);
                                  rankBorder = const Color(0xFFF59E0B);
                                  rankText = const Color(0xFFB45309);
                                } else if (globalRank == 2) {
                                  rankBg = const Color(0xFFF1F5F9);
                                  rankBorder = const Color(0xFF94A3B8);
                                  rankText = const Color(0xFF475569);
                                } else if (globalRank == 3) {
                                  rankBg = const Color(0xFFFFEDD5);
                                  rankBorder = const Color(0xFFFB923C);
                                  rankText = const Color(0xFFC2410C);
                                }

                                String recommendation = 'Steady Sales';
                                if (item.quantity == 0) {
                                  recommendation = '⚠️ Zero orders • Bundle in Promo';
                                } else if (item.quantity <= 2) {
                                  recommendation = '💡 Low volume • Feature in Cashier Upsell';
                                } else if (item.quantity >= 15) {
                                  recommendation = '🔥 High Demand Core Item';
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBFBFB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank Badge
                                      Container(
                                        width: 44,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        decoration: BoxDecoration(
                                          color: rankBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: rankBorder),
                                        ),
                                        child: Text(
                                          '#$globalRank',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: rankText),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Dish Name & Category
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.category,
                                                    style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              recommendation,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: item.quantity == 0 ? const Color(0xFFDC2626) : (item.quantity <= 2 ? const Color(0xFFD97706) : AppTheme.mediumGrey),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Quantity Sold & Total Sales
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _currencyFormat.format(item.revenue),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: item.quantity > 0 ? const Color(0xFF059669) : AppTheme.mediumGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: item.quantity > 0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  '${item.quantity} sold',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: item.quantity > 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                                  ),
                                                ),
                                              ),
                                              if (item.quantity > 0) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '(${share.toStringAsFixed(1)}%)',
                                                  style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const Divider(height: 1, color: AppTheme.cardBorder),
                    const SizedBox(height: 10),

                    // Pagination Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalFilteredCount == 0
                              ? '0 dishes'
                              : 'Showing ${(modalPage - 1) * itemsPerPage + 1} - ${(modalPage * itemsPerPage).clamp(0, totalFilteredCount)} of $totalFilteredCount dishes',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: modalPage > 1
                                  ? () => setModalState(() => modalPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              splashRadius: 16,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page $modalPage of $totalPages',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                              ),
                            ),
                            IconButton(
                              onPressed: modalPage < totalPages
                                  ? () => setModalState(() => modalPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalSummaryPill(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey)),
          ],
        ),
      ],
    );
  }

  Widget _buildModalTabPill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? activeColor : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : AppTheme.adminPrimaryText,
          ),
        ),
      ),
    );
  }

  // ── 3.7 Payment Method Distribution Analytics ──────────────────────────────
  String _normalizePaymentMethod(String? raw) {
    if (raw == null) return 'Cash';
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return 'Cash';
    if (s.contains('split')) return 'Split Payment';
    if (s.contains('gcash') || s.contains('qr') || s.contains('e-wallet')) return 'GCash';
    if (s.contains('cash')) return 'Cash';
    if (s.contains('card') ||
        s.contains('bank') ||
        s.contains('paymongo') ||
        s.contains('online') ||
        s.contains('transfer') ||
        s.contains('deposit')) {
      return 'Bank / Online';
    }
    return 'Cash';
  }

  Map<String, _PaymentDistributionTender> _computePaymentDistribution(List<Map<String, dynamic>> transactions) {
    final Map<String, _PaymentDistributionTender> tenders = {
      'Cash': _PaymentDistributionTender(
        key: 'Cash',
        title: 'Cash',
        color: const Color(0xFF15803D), // Forest Emerald
        icon: Icons.payments_rounded,
        revenue: 0.0,
        count: 0,
        channelRevenue: {'Regular': 0.0, 'Advance': 0.0, 'Reservation': 0.0},
        channelCount: {'Regular': 0, 'Advance': 0, 'Reservation': 0},
      ),
      'GCash': _PaymentDistributionTender(
        key: 'GCash',
        title: 'GCash',
        color: const Color(0xFF0284C7), // Sky Blue
        icon: Icons.qr_code_scanner_rounded,
        revenue: 0.0,
        count: 0,
        channelRevenue: {'Regular': 0.0, 'Advance': 0.0, 'Reservation': 0.0},
        channelCount: {'Regular': 0, 'Advance': 0, 'Reservation': 0},
      ),
      'Split Payment': _PaymentDistributionTender(
        key: 'Split Payment',
        title: 'Split Payment',
        color: const Color(0xFFD97706), // Amber Gold
        icon: Icons.call_split_rounded,
        revenue: 0.0,
        count: 0,
        channelRevenue: {'Regular': 0.0, 'Advance': 0.0, 'Reservation': 0.0},
        channelCount: {'Regular': 0, 'Advance': 0, 'Reservation': 0},
      ),
      'Bank / Online': _PaymentDistributionTender(
        key: 'Bank / Online',
        title: 'Bank / Online',
        color: const Color(0xFF6366F1), // Indigo
        icon: Icons.account_balance_rounded,
        revenue: 0.0,
        count: 0,
        channelRevenue: {'Regular': 0.0, 'Advance': 0.0, 'Reservation': 0.0},
        channelCount: {'Regular': 0, 'Advance': 0, 'Reservation': 0},
      ),
    };

    final periodTransactions = transactions.where((t) {
      final date = t['raw_date'] as DateTime?;
      final isValidRevenue = t['is_valid_revenue'] == true;
      return isValidRevenue && _isDateInSelectedPeriod(date);
    }).toList();

    for (var t in periodTransactions) {
      final rawMethod = t['payment_method']?.toString() ?? '';
      final normalized = _normalizePaymentMethod(rawMethod);
      final amt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;
      final channel = t['type']?.toString() ?? 'Regular';

      final target = tenders[normalized] ?? tenders['Cash']!;
      tenders[target.key] = _PaymentDistributionTender(
        key: target.key,
        title: target.title,
        color: target.color,
        icon: target.icon,
        revenue: target.revenue + amt,
        count: target.count + 1,
        channelRevenue: {
          ...target.channelRevenue,
          channel: (target.channelRevenue[channel] ?? 0.0) + amt,
        },
        channelCount: {
          ...target.channelCount,
          channel: (target.channelCount[channel] ?? 0) + 1,
        },
      );
    }

    return tenders;
  }

  Widget _buildPaymentDistributionSection(
    bool isDesktop,
    List<Map<String, dynamic>> transactions,
    Map<String, dynamic> metrics,
  ) {
    final tenderMap = _computePaymentDistribution(transactions);
    final tenderList = tenderMap.values.toList();

    double totalSettledRevenue = 0.0;
    int totalSettledCount = 0;
    for (var t in tenderList) {
      totalSettledRevenue += t.revenue;
      totalSettledCount += t.count;
    }

    final isRevenueMode = _paymentDistributionMode == 'Revenue';
    final double metricTotal = isRevenueMode ? totalSettledRevenue : totalSettledCount.toDouble();

    // Prepare doughnut slices
    final List<_PaymentPieSlice> slices = [];
    for (var t in tenderList) {
      final val = isRevenueMode ? t.revenue : t.count.toDouble();
      final pct = metricTotal > 0 ? (val / metricTotal) * 100 : 0.0;
      if (val > 0) {
        slices.add(_PaymentPieSlice(
          label: t.title,
          value: val,
          color: t.color,
          percentage: pct,
          count: t.count,
        ));
      }
    }

    // Top tender insight
    _PaymentDistributionTender topTender = tenderList.first;
    for (var t in tenderList) {
      final compareVal = isRevenueMode ? t.revenue : t.count.toDouble();
      final currentTopVal = isRevenueMode ? topTender.revenue : topTender.count.toDouble();
      if (compareVal > currentTopVal) {
        topTender = t;
      }
    }
    final double topPct = metricTotal > 0
        ? ((isRevenueMode ? topTender.revenue : topTender.count.toDouble()) / metricTotal) * 100
        : 0.0;

    // Digital vs Cash ratio
    final double cashRev = tenderMap['Cash']?.revenue ?? 0.0;
    final double digitalRev = (tenderMap['GCash']?.revenue ?? 0.0) +
        (tenderMap['Split Payment']?.revenue ?? 0.0) +
        (tenderMap['Bank / Online']?.revenue ?? 0.0);
    final double digitalPct = totalSettledRevenue > 0 ? (digitalRev / totalSettledRevenue) * 100 : 0.0;
    final double cashPct = totalSettledRevenue > 0 ? (cashRev / totalSettledRevenue) * 100 : 0.0;

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
          // ── Header & View Mode Switcher ──
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                        color: AppTheme.adminPrimaryAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method Distribution',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.adminPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Settlement mix & tender performance across POS, Advance, & Reservations for $_chartSubtitle',
                          style: const TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildPaymentModeToggle(),
              ],
            )
          else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: AppTheme.adminPrimaryAccent,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Payment Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.adminPrimaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Settlement mix across all channels for $_chartSubtitle',
              style: const TextStyle(fontSize: 12, color: AppTheme.adminSecondaryText),
            ),
            const SizedBox(height: 12),
            _buildPaymentModeToggle(),
          ],
          const SizedBox(height: 20),

          // ── Body: Circular Donut Chart & Detailed Tender Breakdown ──
          if (slices.isEmpty || totalSettledCount == 0)
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 44, color: AppTheme.mediumGrey.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                  const Text(
                    'No settled transactions recorded in this period.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.adminSecondaryText),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Payment data updates in real-time as transactions are completed.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey),
                  ),
                ],
              ),
            )
          else if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Interactive Center-Hole Donut Chart + Digital Ratio
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 280,
                        child: SfCircularChart(
                          margin: EdgeInsets.zero,
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            activationMode: ActivationMode.singleTap,
                            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                              final _PaymentPieSlice slice = data;
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          slice.label,
                                          style: const TextStyle(color: AppTheme.warmGold, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isRevenueMode
                                          ? '${_currencyFormat.format(slice.value)} (${slice.percentage.toStringAsFixed(1)}%)'
                                          : '${slice.value.toInt()} orders (${slice.percentage.toStringAsFixed(1)}%)',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                    Text(
                                      '${slice.count} orders reconciled',
                                      style: const TextStyle(color: AppTheme.adminSecondaryText, fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          annotations: <CircularChartAnnotation>[
                            CircularChartAnnotation(
                              widget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRevenueMode ? Icons.payments_outlined : Icons.receipt_long_outlined,
                                    size: 20,
                                    color: AppTheme.adminPrimaryAccent,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      isRevenueMode ? _currencyFormat.format(totalSettledRevenue) : '$totalSettledCount',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.adminPrimaryText,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isRevenueMode ? 'Total Settled' : 'Total Orders',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.adminSecondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          series: <CircularSeries<_PaymentPieSlice, String>>[
                            DoughnutSeries<_PaymentPieSlice, String>(
                              dataSource: slices,
                              xValueMapper: (_PaymentPieSlice data, _) => data.label,
                              yValueMapper: (_PaymentPieSlice data, _) => data.value,
                              pointColorMapper: (_PaymentPieSlice data, _) => data.color,
                              innerRadius: '68%',
                              radius: '95%',
                              enableTooltip: true,
                              animationDuration: 800,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDigitalVsCashRatioCard(cashRev, digitalRev, cashPct, digitalPct),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.xl),

                // Right Column: 4 Tender Breakdown Cards & Reconciliation Insight
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTenderMetricCard(
                              tenderList[0],
                              metricTotal > 0
                                  ? ((isRevenueMode ? tenderList[0].revenue : tenderList[0].count.toDouble()) / metricTotal) * 100
                                  : 0.0,
                              isRevenueMode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTenderMetricCard(
                              tenderList[1],
                              metricTotal > 0
                                  ? ((isRevenueMode ? tenderList[1].revenue : tenderList[1].count.toDouble()) / metricTotal) * 100
                                  : 0.0,
                              isRevenueMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTenderMetricCard(
                              tenderList[2],
                              metricTotal > 0
                                  ? ((isRevenueMode ? tenderList[2].revenue : tenderList[2].count.toDouble()) / metricTotal) * 100
                                  : 0.0,
                              isRevenueMode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTenderMetricCard(
                              tenderList[3],
                              metricTotal > 0
                                  ? ((isRevenueMode ? tenderList[3].revenue : tenderList[3].count.toDouble()) / metricTotal) * 100
                                  : 0.0,
                              isRevenueMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTenderExecutiveInsightBanner(topTender, topPct, isRevenueMode, totalSettledCount),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            // Mobile layout
            SizedBox(
              height: 260,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                tooltipBehavior: TooltipBehavior(enable: true, activationMode: ActivationMode.singleTap),
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isRevenueMode ? _currencyFormat.format(totalSettledRevenue) : '$totalSettledCount',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText),
                        ),
                        Text(
                          isRevenueMode ? 'Total Settled' : 'Total Orders',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.adminSecondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <CircularSeries<_PaymentPieSlice, String>>[
                  DoughnutSeries<_PaymentPieSlice, String>(
                    dataSource: slices,
                    xValueMapper: (_PaymentPieSlice data, _) => data.label,
                    yValueMapper: (_PaymentPieSlice data, _) => data.value,
                    pointColorMapper: (_PaymentPieSlice data, _) => data.color,
                    innerRadius: '68%',
                    radius: '95%',
                    enableTooltip: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDigitalVsCashRatioCard(cashRev, digitalRev, cashPct, digitalPct),
            const SizedBox(height: 14),
            ...tenderList.map((tender) {
              final sharePct = metricTotal > 0
                  ? ((isRevenueMode ? tender.revenue : tender.count.toDouble()) / metricTotal) * 100
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTenderMetricCard(tender, sharePct, isRevenueMode),
              );
            }),
            const SizedBox(height: 10),
            _buildTenderExecutiveInsightBanner(topTender, topPct, isRevenueMode, totalSettledCount),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPaymentToggleOption(
            title: 'Gross Volume (₱)',
            mode: 'Revenue',
            icon: Icons.attach_money_rounded,
          ),
          _buildPaymentToggleOption(
            title: 'Transaction Count (#)',
            mode: 'Count',
            icon: Icons.tag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentToggleOption({
    required String title,
    required String mode,
    required IconData icon,
  }) {
    final isSelected = _paymentDistributionMode == mode;
    return InkWell(
      onTap: () {
        if (_paymentDistributionMode != mode) {
          setState(() => _paymentDistributionMode = mode);
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.adminPrimaryAccent : AppTheme.adminSecondaryText,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.adminPrimaryText : AppTheme.adminSecondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenderMetricCard(_PaymentDistributionTender tender, double sharePct, bool isRevenueMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.cardBorder, width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Tender Title, Percentage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tender.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(tender.icon, size: 15, color: tender.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tender.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.adminPrimaryText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tender.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${sharePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tender.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Value
          Text(
            isRevenueMode ? _currencyFormat.format(tender.revenue) : '${tender.count} Orders',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.adminPrimaryText,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),

          // Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (sharePct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppTheme.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(tender.color),
            ),
          ),
          const SizedBox(height: 8),

          // Order count & AOV
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tender.count} txns settled',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500),
              ),
              Text(
                'Avg: ${_currencyFormat.format(tender.avgOrderValue)}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Mini Channel Breakdown Chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (tender.channelRevenue['Regular']! > 0)
                _buildChannelMiniChip('Walk-in: ${_currencyFormat.format(tender.channelRevenue['Regular']!)}', AppTheme.regularOrderBlue),
              if (tender.channelRevenue['Advance']! > 0)
                _buildChannelMiniChip('Advance: ${_currencyFormat.format(tender.channelRevenue['Advance']!)}', AppTheme.advanceOrderGreen),
              if (tender.channelRevenue['Reservation']! > 0)
                _buildChannelMiniChip('Banquet: ${_currencyFormat.format(tender.channelRevenue['Reservation']!)}', AppTheme.reservationPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildDigitalVsCashRatioCard(double cashRev, double digitalRev, double cashPct, double digitalPct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Digital Settlements: ${digitalPct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF15803D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Cash: ${cashPct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: (digitalPct * 10).round().clamp(0, 1000),
                  child: Container(height: 6, color: const Color(0xFF0284C7)),
                ),
                Expanded(
                  flex: (cashPct * 10).round().clamp(0, 1000),
                  child: Container(height: 6, color: const Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Digital: ${_currencyFormat.format(digitalRev)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w600),
              ),
              Text(
                'Cash: ${_currencyFormat.format(cashRev)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenderExecutiveInsightBanner(
    _PaymentDistributionTender topTender,
    double topPct,
    bool isRevenueMode,
    int totalCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, size: 16, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                children: [
                  const TextSpan(
                    text: 'EXECUTIVE RECONCILIATION: ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: '${topTender.title} is currently the leading tender method, representing ${topPct.toStringAsFixed(1)}% of all ${isRevenueMode ? 'gross revenue settlements' : 'completed transaction volume'}. Total audit count: $totalCount transactions.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPaymentDistribution(
    _ProcessedReportData data,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor borderColor,
  ) {
    // Tally tenders
    double cashRev = 0.0;
    int cashCount = 0;
    double gcashRev = 0.0;
    int gcashCount = 0;
    double splitRev = 0.0;
    int splitCount = 0;
    double onlineRev = 0.0;
    int onlineCount = 0;

    for (var t in data.transactions) {
      if (t['is_valid_revenue'] != true) continue;
      final rawMethod = t['payment_method']?.toString() ?? '';
      final normalized = _normalizePaymentMethod(rawMethod);
      final amt = (t['revenue_amount'] as num?)?.toDouble() ?? 0.0;

      if (normalized == 'Cash') {
        cashRev += amt;
        cashCount++;
      } else if (normalized == 'GCash') {
        gcashRev += amt;
        gcashCount++;
      } else if (normalized == 'Split Payment') {
        splitRev += amt;
        splitCount++;
      } else {
        onlineRev += amt;
        onlineCount++;
      }
    }

    final double totalRev = data.grossRevenue > 0 ? data.grossRevenue : (cashRev + gcashRev + splitRev + onlineRev);
    final safeTotalRev = totalRev > 0 ? totalRev : 1.0;

    final double cashPct = (cashRev / safeTotalRev).clamp(0.0, 1.0);
    final double gcashPct = (gcashRev / safeTotalRev).clamp(0.0, 1.0);
    final double splitPct = (splitRev / safeTotalRev).clamp(0.0, 1.0);
    final double onlinePct = (onlineRev / safeTotalRev).clamp(0.0, 1.0);

    int cashFlex = (cashPct * 1000).toInt();
    int gcashFlex = (gcashPct * 1000).toInt();
    int splitFlex = (splitPct * 1000).toInt();
    int onlineFlex = (onlinePct * 1000).toInt();
    if (cashFlex == 0 && gcashFlex == 0 && splitFlex == 0 && onlineFlex == 0) {
      cashFlex = 1000;
    }

    const cashPdfColor = PdfColor.fromInt(0xFF15803D);   // Forest Green
    const gcashPdfColor = PdfColor.fromInt(0xFF0284C7);  // Sky Blue
    const splitPdfColor = PdfColor.fromInt(0xFFD97706);  // Amber Gold
    const onlinePdfColor = PdfColor.fromInt(0xFF6366F1); // Indigo

    final double digitalRev = gcashRev + splitRev + onlineRev;
    final double digitalPct = (digitalRev / safeTotalRev) * 100;

    pw.Widget tenderBox(String name, double rev, int count, double pct, PdfColor color) {
      final avg = count > 0 ? rev / count : 0.0;
      return pw.Container(
        padding: const pw.EdgeInsets.all(4.5),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
                    ),
                    pw.SizedBox(width: 3),
                    pw.Text(name, style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
                pw.Text('${(pct * 100).toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text(_formatPdfMoney(rev), style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 1),
            pw.Text('${_formatPdfCount(count)} orders | Avg ${_formatPdfMoney(avg)}', style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700)),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.TableBorder.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT SETTLEMENT & TENDER AUDIT (CROSS-CHANNEL)',
                    style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Revenue distribution across Cash, GCash, Split Tender, and Bank/Online settlements',
                    style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFE2E8F0),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                ),
                child: pw.Text(
                  'TENDER RECONCILIATION',
                  style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Proportional Multi-color Flex Bar
          pw.Container(
            height: 9,
            decoration: const pw.BoxDecoration(
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
              color: PdfColor.fromInt(0xFFE2E8F0),
            ),
            child: pw.Row(
              children: [
                if (cashFlex > 0)
                  pw.Expanded(
                    flex: cashFlex,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        color: cashPdfColor,
                        borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(3), bottomLeft: pw.Radius.circular(3)),
                      ),
                    ),
                  ),
                if (gcashFlex > 0)
                  pw.Expanded(
                    flex: gcashFlex,
                    child: pw.Container(color: gcashPdfColor),
                  ),
                if (splitFlex > 0)
                  pw.Expanded(
                    flex: splitFlex,
                    child: pw.Container(color: splitPdfColor),
                  ),
                if (onlineFlex > 0)
                  pw.Expanded(
                    flex: onlineFlex,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        color: onlinePdfColor,
                        borderRadius: pw.BorderRadius.only(topRight: pw.Radius.circular(3), bottomRight: pw.Radius.circular(3)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 4.5),

          // 4 Tender Summary Cards
          pw.Row(
            children: [
              pw.Expanded(child: tenderBox('Cash', cashRev, cashCount, cashPct, cashPdfColor)),
              pw.SizedBox(width: 4),
              pw.Expanded(child: tenderBox('GCash', gcashRev, gcashCount, gcashPct, gcashPdfColor)),
              pw.SizedBox(width: 4),
              pw.Expanded(child: tenderBox('Split Payment', splitRev, splitCount, splitPct, splitPdfColor)),
              pw.SizedBox(width: 4),
              pw.Expanded(child: tenderBox('Bank / Online', onlineRev, onlineCount, onlinePct, onlinePdfColor)),
            ],
          ),
          pw.SizedBox(height: 3.5),

          // Reconciliation Note
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TENDER AUDIT NOTE: ',
                  style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'Digital tender channels (GCash, Split, & Online) represent ${digitalPct.toStringAsFixed(1)}% (${_formatPdfMoney(digitalRev)}) of total sales turnover, while cash settlement accounts for ${(cashPct * 100).toStringAsFixed(1)}% (${_formatPdfMoney(cashRev)}).',
                    style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Location Sales Forecasting Card ───────────────────────────────────────
  Widget _buildLocationForecastingCard() {
    final filteredLocations = _includeOthersInLocations
        ? _locationData
        : _locationData.where((loc) => loc['location']?.toString().toLowerCase() != 'others').toList();
    final topLocations = filteredLocations.take(5).toList();
    final double totalRevenueSum = topLocations.fold<double>(
      0.0,
      (sum, loc) => sum + ((loc['total_revenue'] as num?)?.toDouble() ?? 0.0),
    );

    Color getLocationColor(String locName, int index) {
      if (locName.toLowerCase() == 'others') {
        return const Color(0xFF64748B); // Slate grey for Others
      }
      const cityColors = [
        Color(0xFF0284C7), // Vibrant Ocean/Sky Blue
        Color(0xFFF59E0B), // Warm Amber / Gold
        Color(0xFF10B981), // Fresh Emerald Green
        Color(0xFF8B5CF6), // Vibrant Purple
        Color(0xFFF43F5E), // Vibrant Coral Rose
        Color(0xFF06B6D4), // Vibrant Cyan
      ];
      return cityColors[index % cityColors.length];
    }

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
          const SizedBox(height: 12),
          _buildLocationModeToggle(),
          const SizedBox(height: 16),
          if (topLocations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, color: AppTheme.mediumGrey, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      !_includeOthersInLocations && _locationData.any((l) => l['location']?.toString().toLowerCase() == 'others')
                          ? 'No delivery orders with address recorded in this period.\nAll transactions were walk-in / in-store orders.'
                          : 'No customer location data recorded for this range.',
                      style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    if (!_includeOthersInLocations && _locationData.any((l) => l['location']?.toString().toLowerCase() == 'others')) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _includeOthersInLocations = true),
                        icon: const Icon(Icons.storefront_rounded, size: 14, color: AppTheme.adminPrimaryAccent),
                        label: const Text(
                          'View All Sales (inc. Others)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.adminPrimaryAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.adminPrimaryAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
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
                      final locName = loc['location']?.toString() ?? 'City';
                      final rev = (loc['total_revenue'] as num?)?.toDouble() ?? 0.0;
                      final pct = totalRevenueSum > 0 ? (rev / totalRevenueSum) * 100 : 0.0;
                      final color = getLocationColor(locName, i);
                      return _LocationPieData(
                        locName,
                        rev,
                        '${pct.toStringAsFixed(1)}%',
                        color,
                      );
                    }).toList(),
                    xValueMapper: (_LocationPieData d, _) => d.location,
                    yValueMapper: (_LocationPieData d, _) => d.count,
                    pointColorMapper: (_LocationPieData d, _) => d.color,
                    innerRadius: '65%',
                    radius: '95%',
                    animationDuration: 0,
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
              final locName = loc['location']?.toString() ?? 'Unknown';
              final rev = (loc['total_revenue'] as num?)?.toDouble() ?? 0.0;
              final orderCount = loc['order_count'] ?? 0;
              final pct = totalRevenueSum > 0 ? (rev / totalRevenueSum) : 0.0;
              final color = getLocationColor(locName, idx);

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

  Widget _buildLocationModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              label: 'Cities Only',
              icon: Icons.location_city_rounded,
              isSelected: !_includeOthersInLocations,
              onTap: () => setState(() => _includeOthersInLocations = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildToggleOption(
              label: 'All Sales (inc. Others)',
              icon: Icons.storefront_rounded,
              isSelected: _includeOthersInLocations,
              onTap: () => setState(() => _includeOthersInLocations = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.adminPrimaryAccent : AppTheme.mediumGrey,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.adminPrimaryText : AppTheme.darkGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
        final orderType = t['order_type']?.toString().toLowerCase() ?? '';
        final note = t['note']?.toString().toLowerCase() ?? '';
        if (!id.contains(q) && !rawId.contains(q) && !dbId.contains(q) && !cust.contains(q) && !type.contains(q) && !processedBy.contains(q) && !orderType.contains(q) && !note.contains(q)) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Expanded(
                  flex: 7,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: 180, child: _buildSearchInput()),
                      _buildChannelFilterDropdown(),
                      _buildStatusFilterDropdown(),
                      _buildTransactionPeriodDropdown(),
                    ],
                  ),
                ),
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
              .map((c) => DropdownMenuItem(value: c, child: Text(c == 'Regular' ? 'Walk-in' : c == 'Advance' ? 'Advance' : c == 'Reservation' ? 'Event' : c)))
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
            child: _typeBadge(t['type'], isTakeout: (t['is_pos_takeout'] as bool?) ?? false),
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
              _typeBadge(t['type'], isTakeout: (t['is_pos_takeout'] as bool?) ?? false),
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

  Widget _typeBadge(String type, {bool isTakeout = false}) {
    Color bg;
    Color textColor;
    IconData icon;
    String label = type;

    if (isTakeout) {
      bg = AppTheme.advanceOrderGreen.withValues(alpha: 0.1);
      textColor = AppTheme.advanceOrderGreen;
      icon = Icons.shopping_bag_outlined;
      label = 'Take-out';
    } else {
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
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Showing $start-$end of $totalItems entries', style: const TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText)),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              style: IconButton.styleFrom(
                backgroundColor: _currentPage > 1 ? AppTheme.adminSidebarBackground : AppTheme.adminMainBackground,
                foregroundColor: _currentPage > 1 ? Colors.white : AppTheme.mediumGrey,
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 6),
            Text('Page $_currentPage of $totalPages', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              style: IconButton.styleFrom(
                backgroundColor: _currentPage < totalPages ? AppTheme.adminSidebarBackground : AppTheme.adminMainBackground,
                foregroundColor: _currentPage < totalPages ? Colors.white : AppTheme.mediumGrey,
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
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

class _ReportItemSalesRecord {
  final String name;
  final String category;
  int quantity;
  double revenue;

  _ReportItemSalesRecord({
    required this.name,
    required this.category,
    this.quantity = 0,
    this.revenue = 0.0,
  });
}

class _ReportDailySalesRecord {
  final String dateStr;
  final String dayOfWeek;
  final DateTime date;
  int ordersCount = 0;
  int itemsSold = 0;
  double grossSales = 0.0;

  _ReportDailySalesRecord({
    required this.dateStr,
    required this.dayOfWeek,
    required this.date,
  });
}

class _ReportHourlyBucketRecord {
  final String timeWindow;
  final String servicePeriod;
  int ordersCount = 0;
  int itemsSold = 0;
  double grossSales = 0.0;

  _ReportHourlyBucketRecord({
    required this.timeWindow,
    required this.servicePeriod,
  });
}

class _ProcessedReportData {
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> metrics;
  final Set<String> activeChannels;
  final List<_ReportDailySalesRecord> dailyList;
  final List<_ReportHourlyBucketRecord> hourlyList;
  final List<_ReportItemSalesRecord> bestSellers;
  final List<_ReportItemSalesRecord> lowSellers;
  final int totalQuantitySold;
  final double grossRevenue;
  final double walkInRevenue;
  final double advanceRevenue;
  final double reservationRevenue;
  final int totalOrders;
  final int walkInOrders;
  final int advanceOrders;
  final int reservationOrders;
  final double avgOrderValue;
  final int uniqueCustomers;
  final int lowStockItems;
  final double advCancelRate;
  final double eventCancelRate;
  final String dateRangeStr;
  final String reportPeriodLabel;
  final String generatedBy;
  final DateTime generatedAt;

  bool get isEventOnly => activeChannels.length == 1 && activeChannels.contains('Reservation');
  bool get isAdvanceOnly => activeChannels.length == 1 && activeChannels.contains('Advance');
  bool get isRegularOnly => activeChannels.length == 1 && activeChannels.contains('Regular');
  bool get isAllChannels => activeChannels.length == 3 || activeChannels.isEmpty;

  _ProcessedReportData({
    required this.transactions,
    required this.metrics,
    required this.activeChannels,
    required this.dailyList,
    required this.hourlyList,
    required this.bestSellers,
    required this.lowSellers,
    required this.totalQuantitySold,
    required this.grossRevenue,
    required this.walkInRevenue,
    required this.advanceRevenue,
    required this.reservationRevenue,
    required this.totalOrders,
    required this.walkInOrders,
    required this.advanceOrders,
    required this.reservationOrders,
    required this.avgOrderValue,
    required this.uniqueCustomers,
    required this.lowStockItems,
    required this.advCancelRate,
    required this.eventCancelRate,
    required this.dateRangeStr,
    required this.reportPeriodLabel,
    required this.generatedBy,
    required this.generatedAt,
  });
}

class _PaymentDistributionTender {
  final String key;
  final String title;
  final Color color;
  final IconData icon;
  final double revenue;
  final int count;
  final Map<String, double> channelRevenue;
  final Map<String, int> channelCount;

  _PaymentDistributionTender({
    required this.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.revenue,
    required this.count,
    required this.channelRevenue,
    required this.channelCount,
  });

  double get avgOrderValue => count > 0 ? revenue / count : 0.0;
}

class _PaymentPieSlice {
  final String label;
  final double value;
  final Color color;
  final double percentage;
  final int count;

  _PaymentPieSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.percentage,
    required this.count,
  });
}


