import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/file_download.dart';
import 'package:yang_chow/utils/global_messenger.dart';

/// Data structure representing the forecast breakdown for a single future day.
class DailySalesForecast {
  final DateTime date;
  final String dayName;
  final String dateFormatted;
  final double guaranteedReservationsRevenue;
  final double guaranteedAdvanceRevenue;
  final double guaranteedPipeline;
  final double projectedWalkInRevenue;
  final double totalForecastRevenue;
  final double baseDowRevenue;
  final double momentumFactor;
  final int confirmedReservationsCount;
  final int confirmedAdvanceCount;
  final int totalGuestsCount;
  final double confidenceScore; // 0.0 to 1.0
  final String confidenceLabel;
  final String operationalLoad;
  final Color loadColor;
  final List<Map<String, dynamic>> reservationBookings;
  final List<Map<String, dynamic>> advanceOrderBookings;

  DailySalesForecast({
    required this.date,
    required this.dayName,
    required this.dateFormatted,
    required this.guaranteedReservationsRevenue,
    required this.guaranteedAdvanceRevenue,
    required this.guaranteedPipeline,
    required this.projectedWalkInRevenue,
    required this.totalForecastRevenue,
    required this.baseDowRevenue,
    required this.momentumFactor,
    required this.confirmedReservationsCount,
    required this.confirmedAdvanceCount,
    required this.totalGuestsCount,
    required this.confidenceScore,
    required this.confidenceLabel,
    required this.operationalLoad,
    required this.loadColor,
    required this.reservationBookings,
    required this.advanceOrderBookings,
  });
}

class SalesForecastPage extends StatefulWidget {
  const SalesForecastPage({super.key});

  @override
  State<SalesForecastPage> createState() => _SalesForecastPageState();
}

class _SalesForecastPageState extends State<SalesForecastPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Forecast Horizon Toggle: 7, 14, or 30 days
  int _selectedHorizonDays = 7;

  bool _isLoading = true;
  DateTime _lastRefreshTime = DateTime.now();
  bool _showExplainer = false;

  // Raw Database Records
  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> _rawAdvanceOrders = [];
  List<Map<String, dynamic>> _rawReservations = [];

  // Computed Projections
  List<DailySalesForecast> _dailyForecasts = [];
  Map<int, double> _dowBaselineRevenue = {}; // Day of week (1=Mon ... 7=Sun) -> Avg Revenue
  Map<int, int> _dowBaselineOrders = {};
  Map<int, double> _dowTotalRevenue = {}; // Total revenue for each weekday across 90 days
  Map<int, int> _dowTotalDays = {}; // Total day occurrences sampled in 90 days
  double _totalHistorical90dRevenue = 0.0;
  int _totalHistoricalDaysSampled = 0;
  double _momentumFactor = 1.0; // Growth/Trend multiplier
  double _historicalDailyAvg = 0.0;

  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, // Fully visible by default to prevent invisible render
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _fetchAndCalculateForecast();

    // Auto-refresh every 30 seconds for live dynamic updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchAndCalculateForecast(isSilent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. DATA PIPELINE & FORECAST ENGINE
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _fetchAndCalculateForecast({bool isSilent = false}) async {
    if (!isSilent && _dailyForecasts.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Fetch Historical POS / Walk-in Orders (Last 90 days, paginated to prevent 1000-row cut-off)
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      List<Map<String, dynamic>> allOrders = [];
      const int pageSize = 1000;
      int from = 0;
      bool hasMoreOrders = true;

      while (hasMoreOrders) {
        final ordersChunk = await _supabase
            .from('orders')
            .select()
            .gte('created_at', ninetyDaysAgo)
            .order('created_at', ascending: false)
            .range(from, from + pageSize - 1);
        final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(ordersChunk);
        allOrders.addAll(rows);
        if (rows.length < pageSize || allOrders.length >= 5000) {
          hasMoreOrders = false;
        } else {
          from += pageSize;
        }
      }

      // 2. Fetch ALL Advance Orders (future events scheduled any time)
      // NOTE: Do NOT filter by created_at — a booking created months ago
      // can still have a future pickup date within our horizon.
      final advanceRes = await _supabase
          .from('advance_orders')
          .select()
          .order('created_at', ascending: false)
          .limit(2000);

      // 3. Fetch ALL Event Reservations (future events scheduled any time)
      // NOTE: Same reason — event_date can be far in the future regardless of created_at.
      final reservationsRes = await _supabase
          .from('reservations')
          .select()
          .order('created_at', ascending: false)
          .limit(2000);

      _rawOrders = allOrders;
      _rawAdvanceOrders = List<Map<String, dynamic>>.from(advanceRes);
      _rawReservations = List<Map<String, dynamic>>.from(reservationsRes);

      // Run Predictive Engine
      _computeForecast();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error calculating sales forecast: $e');
      if (mounted) {
        // Even on error, compute forecast with whatever data is loaded
        _computeForecast();
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _computeForecast() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // ── STEP A: Compute Day-of-Week (DOW) Historical Baseline ────────────────
    // Filter valid completed/active orders (exclude cancelled/voided/refunded)
    final validOrders = _rawOrders.where((o) {
      final st = (o['status'] ?? o['kitchen_status'] ?? '').toString().toLowerCase();
      final pSt = (o['payment_status'] ?? '').toString().toLowerCase();
      if (st == 'cancelled' || st == 'voided' || pSt == 'refunded' || pSt == 'cancelled') return false;
      return true;
    }).toList();

    // Group actual orders by date (YYYY-MM-DD)
    // NOTE: Only past completed days (before today midnight) are counted in the baseline
    // so that today's partial sales hours do not drag down today's DOW average.
    final Map<String, double> dailyRevenueMap = {};
    final Map<String, int> dailyOrderCountMap = {};

    for (var o in validOrders) {
      final createdAtStr = o['created_at']?.toString();
      if (createdAtStr == null) continue;
      final dt = DateTime.tryParse(createdAtStr)?.toLocal();
      if (dt == null) continue;

      // Exclude today's incomplete sales from historical baseline
      if (!dt.isBefore(todayMidnight)) continue;

      final key = DateFormat('yyyy-MM-dd').format(dt);
      final amt = (o['total_amount'] as num?)?.toDouble() ??
          (o['total_price'] as num?)?.toDouble() ??
          0.0;
      dailyRevenueMap[key] = (dailyRevenueMap[key] ?? 0.0) + amt;
      dailyOrderCountMap[key] = (dailyOrderCountMap[key] ?? 0) + 1;
    }

    // Group by Day of Week: 1 (Mon) .. 7 (Sun)
    final Map<int, List<double>> dowTotals = {1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []};
    final Map<int, List<int>> dowCounts = {1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []};

    dailyRevenueMap.forEach((dateKey, rev) {
      final dt = DateTime.tryParse(dateKey);
      if (dt != null) {
        dowTotals[dt.weekday]?.add(rev);
        final count = dailyOrderCountMap[dateKey] ?? 1;
        dowCounts[dt.weekday]?.add(count);
      }
    });

    _dowBaselineRevenue.clear();
    _dowBaselineOrders.clear();
    _dowTotalRevenue.clear();
    _dowTotalDays.clear();
    double totalAllDailyRev = 0.0;
    int totalDaysSampled = 0;

    for (int dow = 1; dow <= 7; dow++) {
      final revList = dowTotals[dow] ?? [];
      final countList = dowCounts[dow] ?? [];
      if (revList.isNotEmpty) {
        final sumRev = revList.reduce((a, b) => a + b);
        final avgRev = sumRev / revList.length;
        final avgCnt = (countList.reduce((a, b) => a + b) / countList.length).round();
        _dowBaselineRevenue[dow] = avgRev;
        _dowBaselineOrders[dow] = avgCnt;
        _dowTotalRevenue[dow] = sumRev;
        _dowTotalDays[dow] = revList.length;
        totalAllDailyRev += sumRev;
        totalDaysSampled += revList.length;
      } else {
        _dowBaselineRevenue[dow] = 12000.0; // Reasonable fallback for brand new DB
        _dowBaselineOrders[dow] = 15;
        _dowTotalRevenue[dow] = 12000.0 * 13;
        _dowTotalDays[dow] = 13;
      }
    }
    _totalHistorical90dRevenue = totalAllDailyRev;
    _totalHistoricalDaysSampled = totalDaysSampled;
    _historicalDailyAvg = totalDaysSampled > 0 ? (totalAllDailyRev / totalDaysSampled) : 15000.0;

    // ── STEP B: Compute Recent Growth Momentum (Last 14d vs Previous 14d) ───
    // Apples-to-apples 14 full completed days comparison
    final date14dAgo = todayMidnight.subtract(const Duration(days: 14));
    final date28dAgo = todayMidnight.subtract(const Duration(days: 28));

    double revLast14d = 0.0;
    double revPrev14d = 0.0;

    dailyRevenueMap.forEach((dateKey, rev) {
      final dt = DateTime.tryParse(dateKey);
      if (dt == null) return;
      // Recent 14 full days: [date14dAgo, todayMidnight)
      if (dt.isAfter(date14dAgo.subtract(const Duration(seconds: 1))) && dt.isBefore(todayMidnight)) {
        revLast14d += rev;
      }
      // Previous 14 full days: [date28dAgo, date14dAgo)
      else if (dt.isAfter(date28dAgo.subtract(const Duration(seconds: 1))) && dt.isBefore(date14dAgo)) {
        revPrev14d += rev;
      }
    });

    if (revPrev14d > 1000) {
      final ratio = revLast14d / revPrev14d;
      // Clamp momentum multiplier between 0.85 (-15%) and 1.25 (+25%) for forecast stability
      _momentumFactor = ratio.clamp(0.85, 1.25);
    } else {
      _momentumFactor = 1.0;
    }

    // ── STEP C: Parse and Index Future Advance Orders ────────────────────────
    final Map<String, List<Map<String, dynamic>>> advanceOrdersByDate = {};
    for (var adv in _rawAdvanceOrders) {
      final st = (adv['status'] ?? '').toString().toLowerCase();
      final rSt = (adv['refund_status'] ?? '').toString().toLowerCase();
      final pSt = (adv['payment_status'] ?? '').toString().toLowerCase();
      if (st == 'cancelled' || st == 'rejected' || rSt == 'full_refund' || pSt == 'cancelled') continue;

      DateTime? scheduledDate;
      // Advance pre-orders must be scheduled for a target fulfillment date
      for (final dateKey in ['pickup_date', 'delivery_date', 'order_date']) {
        final val = adv[dateKey]?.toString();
        if (val != null && val.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(val.trim())?.toLocal();
          if (parsed != null) {
            scheduledDate = parsed;
            break;
          }
        }
      }
      if (scheduledDate != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(scheduledDate);
        advanceOrdersByDate.putIfAbsent(dateKey, () => []).add(adv);
      }
    }

    // ── STEP D: Parse and Index Future Event Reservations ───────────────────
    final Map<String, List<Map<String, dynamic>>> reservationsByDate = {};
    for (var res in _rawReservations) {
      final st = (res['status'] ?? '').toString().toLowerCase();
      final rSt = (res['refund_status'] ?? '').toString().toLowerCase();
      final pSt = (res['payment_status'] ?? '').toString().toLowerCase();
      if (st == 'cancelled' || st == 'rejected' || rSt == 'full_refund' || pSt == 'cancelled') continue;

      // Only confirmed/approved bookings or bookings with deposit/payment are guaranteed pipeline
      final isConfirmed = st == 'confirmed' || st == 'approved' || st == 'completed';
      final hasPayment = pSt == 'deposit_paid' || pSt == 'paid' || pSt == 'fully_paid';
      if (!isConfirmed && !hasPayment) continue;

      DateTime? eventDate;
      for (final dateKey in ['event_date', 'reservation_date']) {
        final val = res[dateKey]?.toString();
        if (val != null && val.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(val.trim())?.toLocal();
          if (parsed != null) {
            eventDate = parsed;
            break;
          }
        }
      }
      if (eventDate != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(eventDate);
        reservationsByDate.putIfAbsent(dateKey, () => []).add(res);
      }
    }

    // ── STEP E: Project Each Future Day ──────────────────────────────────────
    final List<DailySalesForecast> forecasts = [];

    for (int dayOffset = 0; dayOffset < _selectedHorizonDays; dayOffset++) {
      final targetDate = todayMidnight.add(Duration(days: dayOffset));
      final dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
      final dow = targetDate.weekday;

      // 1. Confirmed Reservations for this day
      final matchingReservations = reservationsByDate[dateKey] ?? [];
      double resRevenue = 0.0;
      int guestsCount = 0;
      for (var r in matchingReservations) {
        final tot = (r['total_price'] as num?)?.toDouble() ?? 0.0;
        final dep = (r['deposit_amount'] as num?)?.toDouble() ?? (tot / 2);

        // Expected contract value on event day: total price if specified, or deposit fallback
        final contractVal = tot > 0 ? tot : dep;
        resRevenue += contractVal;

        final g = (r['number_of_guests'] as num?)?.toInt() ??
            (r['guest_count'] as num?)?.toInt() ??
            0;
        guestsCount += g;
      }

      // 2. Confirmed Advance Orders for this day
      final matchingAdvance = advanceOrdersByDate[dateKey] ?? [];
      double advRevenue = 0.0;
      for (var a in matchingAdvance) {
        final amt = (a['total_price'] as num?)?.toDouble() ??
            (a['total_amount'] as num?)?.toDouble() ??
            0.0;
        advRevenue += amt;
      }

      // 3. Guaranteed Total Pipeline
      final guaranteedPipeline = resRevenue + advRevenue;

      // 4. Projected Regular Walk-in Revenue (DOW Baseline * Momentum)
      final baseDOW = _dowBaselineRevenue[dow] ?? _historicalDailyAvg;
      final projectedWalkIn = baseDOW * _momentumFactor;

      // 5. Total Daily Forecast
      final totalForecast = guaranteedPipeline + projectedWalkIn;

      // 6. Confidence Score & Operational Load
      final double confidenceRatio = totalForecast > 0
          ? (0.75 + (guaranteedPipeline / totalForecast) * 0.23).clamp(0.75, 0.98)
          : 0.80;

      String confLabel = 'Statistical Estimate';
      if (guaranteedPipeline > (projectedWalkIn * 0.5)) {
        confLabel = 'High (Backed by Bookings)';
      }
      if (guaranteedPipeline >= projectedWalkIn) {
        confLabel = 'Very High (Secured Pipeline)';
      }

      String opLoad = 'Normal Operations';
      Color loadClr = const Color(0xFF10B981);

      if (totalForecast >= _historicalDailyAvg * 1.6 || matchingReservations.length >= 2) {
        opLoad = 'High Demand (Peak)';
        loadClr = const Color(0xFFEF4444);
      } else if (totalForecast >= _historicalDailyAvg * 1.25 || matchingReservations.isNotEmpty) {
        opLoad = 'Busy Kitchen (Busy)';
        loadClr = const Color(0xFFF59E0B);
      } else if (totalForecast >= _historicalDailyAvg * 0.9) {
        opLoad = 'Steady Operations (Steady)';
        loadClr = const Color(0xFF0284C7);
      } else {
        opLoad = 'Light Demand (Light)';
        loadClr = const Color(0xFF10B981);
      }

      forecasts.add(DailySalesForecast(
        date: targetDate,
        dayName: DateFormat('EEE').format(targetDate),
        dateFormatted: DateFormat('MMM d, yyyy').format(targetDate),
        guaranteedReservationsRevenue: resRevenue,
        guaranteedAdvanceRevenue: advRevenue,
        guaranteedPipeline: guaranteedPipeline,
        projectedWalkInRevenue: projectedWalkIn,
        totalForecastRevenue: totalForecast,
        baseDowRevenue: baseDOW,
        momentumFactor: _momentumFactor,
        confirmedReservationsCount: matchingReservations.length,
        confirmedAdvanceCount: matchingAdvance.length,
        totalGuestsCount: guestsCount,
        confidenceScore: confidenceRatio,
        confidenceLabel: confLabel,
        operationalLoad: opLoad,
        loadColor: loadClr,
        reservationBookings: matchingReservations,
        advanceOrderBookings: matchingAdvance,
      ));
    }

    _dailyForecasts = forecasts;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. EXPORT: EXCEL SPREADSHEET
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _exportForecastToExcel() async {
    GlobalMessenger.showInfo('Generating Sales Forecast Excel report...');

    try {
      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      final headerStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );
      final titleStyle = excel_pkg.CellStyle(
        fontSize: 14,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );

      void appendRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        sheet.appendRow(rowValues);
        if (style != null) {
          final rIndex = sheet.maxRows - 1;
          for (var c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rIndex));
            cell.cellStyle = style;
          }
        }
      }

      // SHEET 1: DAILY PROJECTIONS
      final sheet1 = excel['Daily Sales Projections'];
      sheet1.setColumnWidth(0, 18.0);
      sheet1.setColumnWidth(1, 10.0);
      sheet1.setColumnWidth(2, 16.0);
      sheet1.setColumnWidth(3, 16.0);
      sheet1.setColumnWidth(4, 20.0);
      sheet1.setColumnWidth(5, 18.0);
      sheet1.setColumnWidth(6, 20.0);
      sheet1.setColumnWidth(7, 18.0);
      sheet1.setColumnWidth(8, 22.0);

      appendRow(sheet1, [excel_pkg.TextCellValue('YANG CHOW RESTAURANT — SALES FORECAST & PREDICTIVE AUDIT')], style: titleStyle);
      appendRow(sheet1, [excel_pkg.TextCellValue('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} • Horizon: Next $_selectedHorizonDays Days')]);
      sheet1.appendRow([excel_pkg.TextCellValue('')]);

      appendRow(sheet1, [
        excel_pkg.TextCellValue('Date'),
        excel_pkg.TextCellValue('Day'),
        excel_pkg.TextCellValue('Catering / Events'),
        excel_pkg.TextCellValue('Advance Orders'),
        excel_pkg.TextCellValue('Guaranteed (Bookings)'),
        excel_pkg.TextCellValue('Projected Walk-In'),
        excel_pkg.TextCellValue('Total Forecast'),
        excel_pkg.TextCellValue('Confidence'),
        excel_pkg.TextCellValue('Kitchen Status'),
      ], style: headerStyle);

      for (var f in _dailyForecasts) {
        appendRow(sheet1, [
          excel_pkg.TextCellValue(f.dateFormatted),
          excel_pkg.TextCellValue(f.dayName),
          excel_pkg.DoubleCellValue(double.parse(f.guaranteedReservationsRevenue.toStringAsFixed(2))),
          excel_pkg.DoubleCellValue(double.parse(f.guaranteedAdvanceRevenue.toStringAsFixed(2))),
          excel_pkg.DoubleCellValue(double.parse(f.guaranteedPipeline.toStringAsFixed(2))),
          excel_pkg.DoubleCellValue(double.parse(f.projectedWalkInRevenue.toStringAsFixed(2))),
          excel_pkg.DoubleCellValue(double.parse(f.totalForecastRevenue.toStringAsFixed(2))),
          excel_pkg.TextCellValue('${(f.confidenceScore * 100).toStringAsFixed(0)}%'),
          excel_pkg.TextCellValue(f.operationalLoad),
        ]);
      }

      // SHEET 2: CONFIRMED BOOKINGS PIPELINE
      final sheet2 = excel['Confirmed Bookings Pipeline'];
      sheet2.setColumnWidth(0, 16.0);
      sheet2.setColumnWidth(1, 16.0);
      sheet2.setColumnWidth(2, 22.0);
      sheet2.setColumnWidth(3, 20.0);
      sheet2.setColumnWidth(4, 14.0);
      sheet2.setColumnWidth(5, 16.0);
      sheet2.setColumnWidth(6, 16.0);

      appendRow(sheet2, [
        excel_pkg.TextCellValue('Event Date'),
        excel_pkg.TextCellValue('Booking Type'),
        excel_pkg.TextCellValue('Customer Name'),
        excel_pkg.TextCellValue('Details'),
        excel_pkg.TextCellValue('Guests / Pax'),
        excel_pkg.TextCellValue('Amount'),
        excel_pkg.TextCellValue('Payment Status'),
      ], style: headerStyle);

      for (var f in _dailyForecasts) {
        for (var r in f.reservationBookings) {
          appendRow(sheet2, [
            excel_pkg.TextCellValue(f.dateFormatted),
            excel_pkg.TextCellValue('Catering / Event'),
            excel_pkg.TextCellValue(r['customer_name']?.toString() ?? 'Client'),
            excel_pkg.TextCellValue(r['event_type']?.toString() ?? 'Banquet'),
            excel_pkg.IntCellValue((r['number_of_guests'] as num?)?.toInt() ?? 0),
            excel_pkg.DoubleCellValue((r['total_price'] as num?)?.toDouble() ?? 0.0),
            excel_pkg.TextCellValue(r['payment_status']?.toString() ?? 'Confirmed'),
          ]);
        }
        for (var a in f.advanceOrderBookings) {
          final rawType = a['order_type']?.toString().trim();
          final orderType = (rawType != null && rawType.isNotEmpty) ? rawType : 'Pick Up';
          final guests = (a['number_of_guests'] as num?)?.toInt() ?? 1;
          appendRow(sheet2, [
            excel_pkg.TextCellValue(f.dateFormatted),
            excel_pkg.TextCellValue('Advance Pre-Order'),
            excel_pkg.TextCellValue(a['customer_name']?.toString() ?? 'Customer'),
            excel_pkg.TextCellValue('Advance Order ($orderType)'),
            excel_pkg.IntCellValue(guests),
            excel_pkg.DoubleCellValue((a['total_price'] as num?)?.toDouble() ?? 0.0),
            excel_pkg.TextCellValue(a['payment_status']?.toString() ?? 'Paid'),
          ]);
        }
      }

      final excelBytes = excel.save();
      if (excelBytes == null) throw Exception('Excel encoding failed');
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      final fileName = 'Yang_Chow_Sales_Forecast_${_selectedHorizonDays}Days_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

      // 1. Direct Web Download
      if (kIsWeb) {
        final downloaded = downloadBinaryFile(
          bytes,
          '$fileName.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (downloaded) {
          GlobalMessenger.showSuccess('Sales Forecast Excel downloaded: $fileName.xlsx');
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
                final targetPath = '${downloadsDir.path}\\$fileName.xlsx';
                final file = File(targetPath);
                await file.writeAsBytes(bytes);
                GlobalMessenger.showSuccess('Sales Forecast Excel na-save sa Downloads: $fileName.xlsx');
                return;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Save Dialog Fallback via FilePicker (Works universally on Web & Desktop)
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow Sales Forecast Excel Report',
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
        GlobalMessenger.showSuccess('Sales Forecast Excel na-save: $fileName.xlsx');
      }
    } catch (e) {
      GlobalMessenger.showError('Error sa Excel: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. EXPORT: PDF DIRECT DOWNLOAD
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    GlobalMessenger.showInfo('Ginagawa ang Sales Forecast PDF report...');

    try {
      pw.ThemeData? pdfTheme;
      try {
        final fontRegular = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 2));
        final fontBold = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 2));
        pdfTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);
      } catch (_) {}

      final doc = pw.Document(theme: pdfTheme);

      String formatPdfAmt(double val) => 'PHP ${NumberFormat('#,##0.00').format(val)}';
      String cleanText(String s) => s.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();

      final totalProjected = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.totalForecastRevenue);
      final totalGuaranteed = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.guaranteedPipeline);
      final totalWalkIn = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.projectedWalkInRevenue);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'YANG CHOW RESTAURANT & CATERING',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#14332E')),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Sales Forecast & Predictive Analytics Report',
                      style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Next $_selectedHorizonDays Days',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex('#14332E'), thickness: 1.5),
            pw.SizedBox(height: 10),

            // Summary KPI Block
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('TOTAL PROJECTED SALES', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(formatPdfAmt(totalProjected), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#14332E'))),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('GUARANTEED REVENUE (BOOKED)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(formatPdfAmt(totalGuaranteed), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0284C7'))),
                      pw.Text('${totalProjected > 0 ? ((totalGuaranteed / totalProjected) * 100).toStringAsFixed(1) : 0}% of Total', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('ESTIMATED WALK-IN / DINE-IN', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(formatPdfAmt(totalWalkIn), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#F59E0B'))),
                      pw.Text('Based on historical daily sales trend', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Day',
                'Catering / Events',
                'Advance Orders',
                'Guaranteed',
                'Est. Walk-In',
                'Total Forecast',
                'Confidence',
                'Kitchen Status',
              ],
              data: _dailyForecasts.map((f) => [
                f.dateFormatted,
                f.dayName,
                formatPdfAmt(f.guaranteedReservationsRevenue),
                formatPdfAmt(f.guaranteedAdvanceRevenue),
                formatPdfAmt(f.guaranteedPipeline),
                formatPdfAmt(f.projectedWalkInRevenue),
                formatPdfAmt(f.totalForecastRevenue),
                '${(f.confidenceScore * 100).toStringAsFixed(0)}%',
                cleanText(f.operationalLoad),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#14332E')),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 22,
              oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
            ),
          ],
        ),
      );

      // Direct download / save
      final List<int> rawPdf = await doc.save();
      final Uint8List pdfBytes = Uint8List.fromList(rawPdf);
      final fileName = 'Yang_Chow_Sales_Forecast_${_selectedHorizonDays}Days_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      // 1. Direct Web Download
      if (kIsWeb) {
        final downloaded = downloadBinaryFile(pdfBytes, fileName, 'application/pdf');
        if (downloaded) {
          GlobalMessenger.showSuccess('Sales Forecast PDF downloaded: $fileName');
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
                final targetPath = '${downloadsDir.path}\\$fileName';
                final file = File(targetPath);
                await file.writeAsBytes(pdfBytes);
                GlobalMessenger.showSuccess('Sales Forecast PDF saved to Downloads: $fileName');
                return;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Save Dialog Fallback via FilePicker
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow Sales Forecast PDF Report',
        fileName: fileName,
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
        GlobalMessenger.showSuccess('Sales Forecast PDF na-save: $fileName');
        return;
      }

      // 3. Fallback to Printing preview if direct download/save didn't occur
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      GlobalMessenger.showError('Hindi na-download ang PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. MAIN UI BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.adminPrimaryAccent),
                    SizedBox(height: 16),
                    Text(
                      'Calculating projected sales based on confirmed bookings and historical trends...',
                      style: TextStyle(fontSize: 13, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: () => _fetchAndCalculateForecast(isSilent: false),
                  color: AppTheme.adminPrimaryAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : (isTablet ? 20 : 14),
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Notice: $_errorMessage (showing computed baseline estimates)',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _fetchAndCalculateForecast(isSilent: false),
                                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _buildExecutiveHeader(isDesktop),
                        const SizedBox(height: 18),
                        _buildAdminExplainerGuide(isDesktop),
                        const SizedBox(height: 18),
                        _buildHeroKpiGrid(isDesktop, isTablet),
                        const SizedBox(height: 24),
                        _buildMainChartsSection(isDesktop),
                        const SizedBox(height: 24),
                        _buildOperationalAlertsCard(),
                        const SizedBox(height: 24),
                        _buildDayByDayScheduleTable(isDesktop),
                        const SizedBox(height: 24),
                        _buildConfirmedPipelineFeed(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. EXECUTIVE HEADER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildExecutiveHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14332E).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Sales Forecast & Predictive Analytics',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.adminPrimaryText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'LIVE • SYSTEM CONNECTED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Projected store revenue and demand forecasting based on confirmed reservations, advance pre-orders, and historical walk-in dining trends.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.adminSecondaryText.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 16),

          // Controls Bar (Horizon Selector + Export Actions)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;

              final horizonSelector = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Horizon:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.adminSecondaryText),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.adminMainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHorizonChip('7 Days (1 Week)', 7),
                          _buildHorizonChip('14 Days (2 Weeks)', 14),
                          _buildHorizonChip('Full Month (30 Days)', 30),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _fetchAndCalculateForecast(isSilent: false),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Refresh (${DateFormat('hh:mm a').format(_lastRefreshTime)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.adminPrimaryText,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportForecastToExcel,
                    icon: const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF16A34A)),
                    label: const Text('Export to Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      backgroundColor: const Color(0xFFF0FDF4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.white),
                    label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14332E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    horizonSelector,
                    Flexible(child: actionButtons),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  horizonSelector,
                  const SizedBox(height: 12),
                  actionButtons,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5.1 GABAY PARA KAY ADMIN (PLAIN EXPLAINER GUIDE)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAdminExplainerGuide(bool isDesktop) {
    if (!_showExplainer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF15803D)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'How is Sales Forecast Calculated? Sum of Confirmed Advance Bookings + Estimated POS Walk-in.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _showExplainer = true),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Methodology',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF15803D)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF15803D), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Guide: How is Sales Forecast Calculated?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Intuitive & Transparent! Projected turnover combines two distinct components:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showExplainer = false),
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF166534)),
                tooltip: 'Hide guide',
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 780;
              final items = [
                _buildGuideStepCard(
                  stepNum: '1',
                  title: 'Guaranteed Revenue (Booked)',
                  desc: 'From approved Catering Reservations and Advance Pre-Orders confirmed in the system.',
                  color: const Color(0xFF0284C7),
                  icon: Icons.verified_rounded,
                ),
                _buildGuideStepCard(
                  stepNum: '2',
                  title: 'Estimated Walk-In & Dine-In',
                  desc: 'Calculated from historical restaurant sales (typically higher Friday through Sunday).',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.storefront_rounded,
                ),
                _buildGuideStepCard(
                  stepNum: '=',
                  title: 'Total Projected Gross Sales',
                  desc: 'Combined Bookings + Walk-In to guide admin in purchasing ingredients and scheduling staff.',
                  color: const Color(0xFF14332E),
                  icon: Icons.payments_rounded,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((w) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: w,
                            ),
                          ))
                      .toList(),
                );
              } else {
                return Column(
                  children: items
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: w,
                          ))
                      .toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStepCard({
    required String stepNum,
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonChip(String label, int days) {
    final isSelected = _selectedHorizonDays == days;
    return GestureDetector(
      onTap: () {
        if (_selectedHorizonDays != days) {
          setState(() => _selectedHorizonDays = days);
          // Re-fetch from DB so future events beyond the old horizon are included
          _fetchAndCalculateForecast(isSilent: true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.adminSecondaryText,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. HERO KPI GRID
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeroKpiGrid(bool isDesktop, bool isTablet) {
    final totalProjected = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.totalForecastRevenue);
    final totalGuaranteed = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.guaranteedPipeline);
    final totalWalkIn = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.projectedWalkInRevenue);

    // Identify Peak Day
    DailySalesForecast? peakDay;
    if (_dailyForecasts.isNotEmpty) {
      peakDay = _dailyForecasts.reduce((curr, next) => curr.totalForecastRevenue > next.totalForecastRevenue ? curr : next);
    }

    final totalBookings = _dailyForecasts.fold<int>(0, (sum, f) => sum + f.confirmedReservationsCount + f.confirmedAdvanceCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 880
            ? 4
            : (constraints.maxWidth > 520 ? 2 : 1);
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            // 1. Featured Total Projected Card (Hero Green Gradient)
            SizedBox(
              width: cardWidth,
              child: _buildFeaturedKpiCard(
                title: 'PROJECTED GROSS SALES',
                value: _currencyFormat.format(totalProjected),
                subtitle: 'Next $_selectedHorizonDays days',
                chipLabel: '${(_momentumFactor >= 1.0 ? '+' : '')}${((_momentumFactor - 1.0) * 100).toStringAsFixed(1)}%',
                chipColor: _momentumFactor >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                icon: Icons.payments_rounded,
              ),
            ),

            // 2. Guaranteed Pipeline Card
            SizedBox(
              width: cardWidth,
              child: _buildStandardKpiCard(
                title: 'GUARANTEED REVENUE',
                value: _currencyFormat.format(totalGuaranteed),
                subtitle: '$totalBookings confirmed bookings',
                badgeText: 'CONFIRMED',
                badgeColor: const Color(0xFF0284C7),
                icon: Icons.verified_rounded,
                accentColor: const Color(0xFF0284C7),
              ),
            ),

            // 3. Projected Walk-in Sales Card
            SizedBox(
              width: cardWidth,
              child: _buildStandardKpiCard(
                title: 'ESTIMATED DINE-IN / WALK-IN',
                value: _currencyFormat.format(totalWalkIn),
                subtitle: 'Based on regular sales trend',
                badgeText: 'REGULAR',
                badgeColor: const Color(0xFFF59E0B),
                icon: Icons.storefront_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
            ),

            // 4. Projected Peak Day Card
            SizedBox(
              width: cardWidth,
              child: _buildStandardKpiCard(
                title: 'PEAK SALES DAY',
                value: peakDay != null ? peakDay.dayName.toUpperCase() : 'N/A',
                subtitle: peakDay != null
                    ? '${peakDay.dateFormatted} • ${_currencyFormat.format(peakDay.totalForecastRevenue)}'
                    : 'No data',
                badgeText: peakDay?.operationalLoad ?? 'Normal',
                badgeColor: peakDay?.loadColor ?? const Color(0xFF10B981),
                icon: Icons.local_fire_department_rounded,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required String chipLabel,
    required Color chipColor,
    required IconData icon,
  }) {
    return Container(
      height: 122,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14332E), Color(0xFF1A453E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.25),
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
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD9A441),
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: chipColor),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFFD9A441)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFC7D6D3), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      height: 122,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.adminSecondaryText,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.adminPrimaryText,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. MAIN CHARTS SECTION (Timeline Spline + Channel Share)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMainChartsSection(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: _buildTimelineForecastChart()),
          const SizedBox(width: 24),
          Expanded(flex: 4, child: _buildChannelShareDoughnut()),
        ],
      );
    } else {
      return Column(
        children: [
          _buildTimelineForecastChart(),
          const SizedBox(height: 24),
          _buildChannelShareDoughnut(),
        ],
      );
    }
  }

  Widget _buildTimelineForecastChart() {
    if (_dailyForecasts.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: AppTheme.adminPrimaryAccent)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF14332E)),
                      SizedBox(width: 8),
                      Text(
                        'Daily Projected Revenue Trends',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Daily projected sales trajectory combining confirmed advance bookings and estimated regular walk-in dining',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
                  ),
                ],
              ),
              // Legend
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _buildLegendIndicator('Guaranteed (Bookings)', const Color(0xFF0284C7)),
                  _buildLegendIndicator('Estimated Walk-In', const Color(0xFFF59E0B)),
                  _buildLegendIndicator('Total Projected Sales', const Color(0xFF8B5CF6)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 340,
            child: SfCartesianChart(
              margin: const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 8),
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.adminSecondaryText),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.compactCurrency(symbol: '₱'),
                majorGridLines: const MajorGridLines(width: 0.5, color: AppTheme.cardBorder),
                labelStyle: const TextStyle(fontSize: 10, color: AppTheme.adminSecondaryText),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                header: '',
                canShowMarker: true,
                elevation: 10,
                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                  if (pointIndex < 0 || pointIndex >= _dailyForecasts.length) return const SizedBox.shrink();
                  final f = _dailyForecasts[pointIndex];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Date
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 10),
                            const SizedBox(width: 4),
                            Text('${f.dayName}, ${f.dateFormatted}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 5),

                        // Total
                        _tooltipRow(const Color(0xFF8B5CF6), 'Total Projected Revenue'),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 1, bottom: 2),
                          child: Text(_currencyFormat.format(f.totalForecastRevenue),
                              style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w900, fontSize: 12)),
                        ),

                        // Naka-Book
                        _tooltipRow(const Color(0xFF0284C7), 'Guaranteed (Booked)'),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 1, bottom: 2),
                          child: Text(_currencyFormat.format(f.guaranteedPipeline),
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 10.5)),
                        ),

                        // Walk-In
                        _tooltipRow(const Color(0xFFF59E0B), 'Estimated Walk-In / Dine-In'),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 1, bottom: 2),
                          child: Text(_currencyFormat.format(f.projectedWalkInRevenue),
                              style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w700, fontSize: 10.5)),
                        ),

                        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 4),

                        // Operational Load
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 9.5, color: Colors.white38),
                            const SizedBox(width: 4),
                            const Text('Kitchen Status: ', style: TextStyle(color: Colors.white38, fontSize: 9)),
                            Flexible(
                              child: Text(f.operationalLoad,
                                  style: TextStyle(color: f.loadColor, fontWeight: FontWeight.w700, fontSize: 9)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              series: <CartesianSeries<DailySalesForecast, String>>[
                // Stacked Column: Guaranteed Bookings
                StackedColumnSeries<DailySalesForecast, String>(
                  dataSource: _dailyForecasts,
                  xValueMapper: (DailySalesForecast f, _) => '${f.dayName}\n${DateFormat('M/d').format(f.date)}',
                  yValueMapper: (DailySalesForecast f, _) => f.guaranteedPipeline,
                  name: 'Guaranteed Pipeline',
                  color: const Color(0xFF0284C7).withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  animationDuration: 0,
                ),
                // Stacked Column: Projected Walk-in
                StackedColumnSeries<DailySalesForecast, String>(
                  dataSource: _dailyForecasts,
                  xValueMapper: (DailySalesForecast f, _) => '${f.dayName}\n${DateFormat('M/d').format(f.date)}',
                  yValueMapper: (DailySalesForecast f, _) => f.projectedWalkInRevenue,
                  name: 'Projected Walk-In',
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  animationDuration: 0,
                ),
                // Spline Line: Total Projected Curve
                SplineSeries<DailySalesForecast, String>(
                  dataSource: _dailyForecasts,
                  xValueMapper: (DailySalesForecast f, _) => '${f.dayName}\n${DateFormat('M/d').format(f.date)}',
                  yValueMapper: (DailySalesForecast f, _) => f.totalForecastRevenue,
                  name: 'Total Forecast',
                  color: const Color(0xFF8B5CF6),
                  width: 3,
                  animationDuration: 0,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    height: 7,
                    width: 7,
                    color: Color(0xFF8B5CF6),
                    borderColor: Colors.white,
                    borderWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelShareDoughnut() {
    if (_dailyForecasts.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(color: AppTheme.adminPrimaryAccent)),
      );
    }
    final resRev = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.guaranteedReservationsRevenue);
    final advRev = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.guaranteedAdvanceRevenue);
    final walkInRev = _dailyForecasts.fold<double>(0.0, (sum, f) => sum + f.projectedWalkInRevenue);
    final total = resRev + advRev + walkInRev;

    final chartData = [
      _ChannelPieSlice('Catering / Events', resRev, const Color(0xFF14332E)),
      _ChannelPieSlice('Advance Pre-Orders', advRev, const Color(0xFF0284C7)),
      _ChannelPieSlice('Walk-In / Dine-In', walkInRev, const Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF14332E)),
              SizedBox(width: 8),
              Text(
                'Revenue Channel Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Channel contribution to overall projected gross sales',
            style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 180,
            child: SfCircularChart(
              margin: EdgeInsets.zero,
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.adminSecondaryText),
                      ),
                      Text(
                        NumberFormat.compactCurrency(symbol: '₱').format(total),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF14332E)),
                      ),
                    ],
                  ),
                ),
              ],
              series: <CircularSeries<_ChannelPieSlice, String>>[
                DoughnutSeries<_ChannelPieSlice, String>(
                  dataSource: chartData,
                  xValueMapper: (_ChannelPieSlice d, _) => d.channel,
                  yValueMapper: (_ChannelPieSlice d, _) => d.revenue,
                  pointColorMapper: (_ChannelPieSlice d, _) => d.color,
                  innerRadius: '68%',
                  radius: '95%',
                  animationDuration: 0,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Channel Breakdown List
          ...chartData.map((slice) {
            final pct = total > 0 ? (slice.revenue / total) * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slice.channel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.adminPrimaryText),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(slice.revenue),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.adminPrimaryText),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.adminSecondaryText),
        ),
      ],
    );
  }

  Widget _tooltipRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. OPERATIONAL ALERTS & PREP ADVISOR
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildOperationalAlertsCard() {
    // Find peak days with heavy catering bookings
    final highVolumeDays = _dailyForecasts.where((f) => f.operationalLoad.contains('Peak') || f.operationalLoad.contains('Busy') || f.confirmedReservationsCount > 0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kitchen, Inventory & Staffing Advisory',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 6),
                if (highVolumeDays.isNotEmpty) ...[
                  Text(
                    'High customer traffic expected on: ${highVolumeDays.map((d) => '${d.dayName} (${d.dateFormatted})').join(', ')}. Recommend ordering kitchen supplies early and scheduling additional staff to avoid bottlenecks.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.35),
                  ),
                ] else ...[
                  const Text(
                    'Normal customer volume expected during this period. Standard staffing and regular inventory levels are sufficient.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. DAY-BY-DAY FORECAST SCHEDULE TABLE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildDayByDayScheduleTable(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Projected Sales Schedule',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Daily revenue breakdown: confirmed bookings and estimated walk-in customers',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: _showFormulaExplanationDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calculate_outlined, size: 14, color: Color(0xFF334155)),
                            SizedBox(width: 5),
                            Text(
                              'How It Works',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.adminMainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        '${_dailyForecasts.length}-day forecast',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.adminSecondaryText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),

          // Formula Banner (Clean, Neutral, Educational)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final textWidget = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.functions_rounded, size: 16, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                          children: [
                            const TextSpan(text: 'Forecasting Formula: ', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                            const TextSpan(text: 'Total Projected = '),
                            const TextSpan(text: 'Guaranteed (Bookings)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const TextSpan(text: ' + ['),
                            const TextSpan(text: 'Historical Day-of-Week (90-Day Baseline)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const TextSpan(text: ' × '),
                            TextSpan(text: 'Sales Trend (${_momentumFactor.toStringAsFixed(3)})', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const TextSpan(text: ']'),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                final detailBtn = Align(
                  alignment: isNarrow ? Alignment.centerRight : Alignment.center,
                  child: TextButton(
                    onPressed: _showFormulaExplanationDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF14332E),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded, size: 12),
                      ],
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textWidget,
                      const SizedBox(height: 6),
                      detailBtn,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: textWidget),
                    const SizedBox(width: 8),
                    detailBtn,
                  ],
                );
              },
            ),
          ),

          if (isDesktop) ...[
            // Desktop Table Header
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('DATE & DAY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GUARANTEED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                        Text('(Catering & Advance)', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ESTIMATED WALK-IN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                        Text('(90-Day Baseline × Trend)', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL PROJECTED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                        Text('(Guaranteed + Walk-In)', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('KITCHEN STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text('ACTION', textAlign: TextAlign.end, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.adminSecondaryText)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),

            // Rows
            // Desktop Table Rows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailyForecasts.length,
              itemBuilder: (context, index) {
                final f = _dailyForecasts[index];
                final hasBookings = f.confirmedReservationsCount > 0 || f.confirmedAdvanceCount > 0;
                final isHeavy = f.operationalLoad.contains('Busy') || f.operationalLoad.contains('Peak');

                return Container(
                  color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Date & Day
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Text(
                                  f.dayName,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.dateFormatted,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                ),
                                Text(
                                  hasBookings
                                      ? '${f.confirmedReservationsCount} Event${f.confirmedReservationsCount != 1 ? 's' : ''} • ${f.confirmedAdvanceCount} Pre-Order'
                                      : 'No scheduled events',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Guaranteed Pipeline (Bookings)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currencyFormat.format(f.guaranteedPipeline),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: f.guaranteedPipeline > 0 ? FontWeight.w800 : FontWeight.w500,
                                color: f.guaranteedPipeline > 0 ? const Color(0xFF0F172A) : AppTheme.mediumGrey,
                              ),
                            ),
                            Text(
                              f.totalGuestsCount > 0 ? '${f.totalGuestsCount} guests' : 'No bookings',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText),
                            ),
                          ],
                        ),
                      ),

                      // Projected Walk-in
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(f.projectedWalkInRevenue),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),

                      // Total Projected Revenue
                      Expanded(
                        flex: 3,
                        child: Text(
                          _currencyFormat.format(f.totalForecastRevenue),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF14332E),
                          ),
                        ),
                      ),

                      // Operational Load Badge (Kitchen Status)
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isHeavy ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isHeavy ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              isHeavy ? 'Busy' : 'Steady',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isHeavy ? const Color(0xFF92400E) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Action Button: View Details
                      SizedBox(
                        width: 110,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _showDayDetailDialog(f),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: hasBookings
                                    ? const Color(0xFF14332E).withValues(alpha: 0.08)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasBookings
                                      ? const Color(0xFF14332E).withValues(alpha: 0.18)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasBookings ? Icons.event_note_rounded : Icons.calculate_outlined,
                                    size: 12,
                                    color: hasBookings ? const Color(0xFF14332E) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasBookings ? 'View' : 'Details',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: hasBookings ? const Color(0xFF14332E) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            // Mobile Card View
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailyForecasts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (context, index) {
                final f = _dailyForecasts[index];
                final hasBookings = f.confirmedReservationsCount > 0 || f.confirmedAdvanceCount > 0;
                final isHeavy = f.operationalLoad.contains('Busy') || f.operationalLoad.contains('Peak');

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${f.dayName}, ${f.dateFormatted}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isHeavy ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isHeavy ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              isHeavy ? 'Busy' : 'Steady',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isHeavy ? const Color(0xFF92400E) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Guaranteed (Bookings)', style: TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText)),
                              Text(
                                _currencyFormat.format(f.guaranteedPipeline),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: f.guaranteedPipeline > 0 ? const Color(0xFF0F172A) : AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Est. Walk-In', style: TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText)),
                              Text(
                                _currencyFormat.format(f.projectedWalkInRevenue),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total', style: TextStyle(fontSize: 10.5, color: AppTheme.adminSecondaryText)),
                              Text(
                                _currencyFormat.format(f.totalForecastRevenue),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF14332E)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showDayDetailDialog(f),
                          icon: Icon(
                            hasBookings ? Icons.event_note_rounded : Icons.calculate_outlined,
                            size: 14,
                            color: const Color(0xFF14332E),
                          ),
                          label: Text(
                            hasBookings
                                ? 'View (${f.confirmedReservationsCount + f.confirmedAdvanceCount} Bookings & Math)'
                                : 'View Calculation',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF14332E)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 10. CONFIRMED PIPELINE FEED
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildConfirmedPipelineFeed() {
    final allUpcomingBookings = <Map<String, dynamic>>[];

    for (var f in _dailyForecasts) {
      for (var r in f.reservationBookings) {
        allUpcomingBookings.add({
          'type': 'Catering / Event',
          'date': f.dateFormatted,
          'customer': r['customer_name'] ?? 'Client',
          'detail': r['event_type'] ?? 'Banquet',
          'amount': (r['total_price'] as num?)?.toDouble() ?? 0.0,
          'deposit': (r['deposit_amount'] as num?)?.toDouble() ?? 0.0,
          'guests': (r['number_of_guests'] as num?)?.toInt() ?? 0,
          'status': r['payment_status'] ?? 'Confirmed',
          'color': const Color(0xFF14332E),
          'icon': Icons.celebration_rounded,
        });
      }
      for (var a in f.advanceOrderBookings) {
        final rawType = a['order_type']?.toString().trim();
        final orderType = (rawType != null && rawType.isNotEmpty) ? rawType : 'Pick Up';
        final isDineIn = orderType.toLowerCase().contains('dine');
        allUpcomingBookings.add({
          'type': 'Advance Pre-Order',
          'date': f.dateFormatted,
          'customer': a['customer_name'] ?? 'Customer',
          'detail': 'Advance Order ($orderType)',
          'amount': (a['total_price'] as num?)?.toDouble() ?? 0.0,
          'deposit': (a['total_price'] as num?)?.toDouble() ?? 0.0,
          'guests': (a['number_of_guests'] as num?)?.toInt() ?? (isDineIn ? 1 : 0),
          'status': a['payment_status'] ?? 'Paid',
          'color': isDineIn ? const Color(0xFF0D9488) : const Color(0xFF0284C7),
          'icon': isDineIn ? Icons.restaurant_rounded : Icons.takeout_dining_rounded,
        });
      }
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF14332E)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Upcoming Confirmed Bookings Pipeline',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${allUpcomingBookings.length} Active Bookings',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Scheduled catering events and advance pre-orders confirmed within the selected horizon',
            style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
          ),
          const SizedBox(height: 20),

          if (allUpcomingBookings.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_rounded, size: 40, color: AppTheme.mediumGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    const Text(
                      'No upcoming catering events or advance orders in this period.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.adminSecondaryText),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allUpcomingBookings.length > 8 ? 8 : allUpcomingBookings.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (context, idx) {
                final b = allUpcomingBookings[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (b['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(b['icon'] as IconData, size: 18, color: b['color'] as Color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  b['customer'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (b['color'] as Color).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    b['type'] as String,
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: b['color'] as Color),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${b['date']} • ${b['detail']}${b['guests'] > 1 ? ' (${b['guests']} guests)' : ''}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(b['amount']),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText),
                          ),
                          Text(
                            (b['status'] as String).toUpperCase(),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 11. DAY DETAIL DIALOG (SHOW EXACT BOOKINGS)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showDayDetailDialog(DailySalesForecast f) {
    final hasBookings = f.confirmedReservationsCount > 0 || f.confirmedAdvanceCount > 0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.dayName}, ${f.dateFormatted}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Forecast: ${_currencyFormat.format(f.totalForecastRevenue)} • ${f.operationalLoad}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dedicated Calculation Breakdown Box for this specific day
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_outlined, size: 15, color: Color(0xFF14332E)),
                                SizedBox(width: 6),
                                Text(
                                  'CALCULATION BREAKDOWN FOR THIS DAY',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF14332E), letterSpacing: 0.4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Row 1: Guaranteed (Bookings)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('1. Guaranteed Pipeline (Bookings):', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                                Text(
                                  _currencyFormat.format(f.guaranteedPipeline),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: f.guaranteedPipeline > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            if (f.guaranteedPipeline > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  '(${f.confirmedReservationsCount} Event: ${_currencyFormat.format(f.guaranteedReservationsRevenue)} + ${f.confirmedAdvanceCount} Pre-Order: ${_currencyFormat.format(f.guaranteedAdvanceRevenue)})',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ),
                            const SizedBox(height: 6),
                            // Row 2: Projected Walk-In
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('2. Estimated Walk-In (DOW × Trend):', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                                Text(
                                  _currencyFormat.format(f.projectedWalkInRevenue),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12, top: 2),
                              child: Text(
                                '(90-Day Baseline for ${f.dayName}: ${_currencyFormat.format(f.baseDowRevenue)} [from ${_currencyFormat.format(_dowTotalRevenue[f.date.weekday] ?? (f.baseDowRevenue * 13))} across ${_dowTotalDays[f.date.weekday] ?? 13} ${f.dayName}s] × Trend: ${f.momentumFactor.toStringAsFixed(3)})',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ),
                            // Row 3: Total Projected
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Projected Revenue (1 + 2):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                Text(
                                  _currencyFormat.format(f.totalForecastRevenue),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF14332E)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (!hasBookings) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No scheduled catering events or advance pre-orders on this day. Total projected sales is driven by the 90-day walk-in baseline of the restaurant.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (f.reservationBookings.isNotEmpty) ...[
                        const Text('CONFIRMED CATERING / EVENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF14332E), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...f.reservationBookings.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.celebration_rounded, color: Color(0xFF14332E), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['customer_name']?.toString() ?? 'Client', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                                    Text('${r['event_type'] ?? 'Banquet'} • ${r['number_of_guests'] ?? 0} Guests / Pax', style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText)),
                                  ],
                                ),
                              ),
                              Text(_currencyFormat.format((r['total_price'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14332E))),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      if (f.advanceOrderBookings.isNotEmpty) ...[
                        const Text('CONFIRMED ADVANCE / PRE-ORDERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...f.advanceOrderBookings.map((a) {
                          final rawType = a['order_type']?.toString().trim();
                          final orderType = (rawType != null && rawType.isNotEmpty) ? rawType : 'Pick Up';
                          final isDineIn = orderType.toLowerCase().contains('dine');
                          final typeColor = isDineIn ? const Color(0xFF0D9488) : const Color(0xFF0284C7);
                          final guests = (a['number_of_guests'] as num?)?.toInt();
                          final guestsText = (isDineIn && guests != null && guests > 0) ? ' • $guests guests' : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isDineIn ? Icons.restaurant_rounded : Icons.takeout_dining_rounded,
                                    color: typeColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      Text('Advance Order ($orderType$guestsText) • Payment: ${a['payment_status'] ?? 'Paid'}', style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText)),
                                    ],
                                  ),
                                ),
                                Text(_currencyFormat.format((a['total_price'] as num?)?.toDouble() ?? 0.0), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: typeColor)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 12. FORMULA EXPLANATION DIALOG (PAANO KINUKWENTA ANG TANYA)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showFormulaExplanationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_outlined, size: 22, color: Color(0xFF14332E)),
                      SizedBox(width: 8),
                      Text(
                        'How is Sales Forecast Calculated?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.adminPrimaryText),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Explanation of Yang Chow predictive sales forecasting methodology',
                style: TextStyle(fontSize: 11.5, color: AppTheme.adminSecondaryText),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pormula Summary Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CORE FORECASTING FORMULA',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF14332E), letterSpacing: 0.5),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Total Projected Revenue = Guaranteed Pipeline (Bookings) + Estimated Walk-In',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'where:  Estimated Walk-In = (Day-of-Week 90-Day Baseline) × Sales Momentum Trend',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Step 1: Guaranteed Pipeline
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guaranteed Pipeline (Confirmed Bookings)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Directly pulled from the database for all confirmed Catering Events and Advance Pre-Orders (Take-out/Pick-up/Delivery) scheduled for that specific date. This represents 100% committed revenue backed by reservations or deposits.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Step 2: Estimated Walk-In
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Estimated Dine-In & Walk-In Customers',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '• 90-Day Day-of-Week Baseline: Computes historical average daily sales for each specific day of the week over the trailing 90 days. Total restaurant historical revenue sampled: ${_currencyFormat.format(_totalHistorical90dRevenue)} across $_totalHistoricalDaysSampled recorded days.',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '• Sales Momentum Trend (${_momentumFactor.toStringAsFixed(3)}): Evaluates recent sales velocity by comparing the trailing 14 days against the prior 14 days to capture current growth or seasonality. Clamped safely between 0.85 and 1.25 to prevent outlier swings.',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Talaan ng 90-Araw na Rekord ng Benta
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '90-DAY HISTORICAL REVENUE & BASELINE SUMMARY',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF14332E), letterSpacing: 0.3),
                                      ),
                                      Text(
                                        'Total: ${_currencyFormat.format(_totalHistorical90dRevenue)} ($_totalHistoricalDaysSampled days)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF14332E)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Expanded(flex: 2, child: Text('DAY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                                      Expanded(flex: 3, child: Text('TOTAL REVENUE (90d)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                                      Expanded(flex: 2, child: Text('COUNT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                                      Expanded(flex: 3, child: Text('BASELINE (AVERAGE)', textAlign: TextAlign.end, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                                    ],
                                  ),
                                  const Divider(height: 10, color: Color(0xFFE2E8F0)),
                                  ...[
                                    {'dow': 1, 'name': 'Monday'},
                                    {'dow': 2, 'name': 'Tuesday'},
                                    {'dow': 3, 'name': 'Wednesday'},
                                    {'dow': 4, 'name': 'Thursday'},
                                    {'dow': 5, 'name': 'Friday'},
                                    {'dow': 6, 'name': 'Saturday'},
                                    {'dow': 7, 'name': 'Sunday'},
                                  ].map((d) {
                                    final dow = d['dow'] as int;
                                    final name = d['name'] as String;
                                    final totRev = _dowTotalRevenue[dow] ?? ((_dowBaselineRevenue[dow] ?? 0.0) * 13);
                                    final days = _dowTotalDays[dow] ?? 13;
                                    final avgRev = _dowBaselineRevenue[dow] ?? (totRev / (days > 0 ? days : 1));
                                    final isFri = dow == 5;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: isFri ? FontWeight.w800 : FontWeight.w600,
                                                color: isFri ? const Color(0xFF14332E) : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _currencyFormat.format(totRev),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: isFri ? FontWeight.w700 : FontWeight.w500,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '$days days',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _currencyFormat.format(avgRev),
                                              textAlign: TextAlign.end,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isFri ? const Color(0xFF14332E) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Step 3: Synthesis
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Synthesis (Total Projected Gross Sales)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.adminPrimaryText),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Aggregates guaranteed bookings with projected walk-in demand for every upcoming day. This provides management with actionable visibility for raw ingredient procurement and optimal staff rostering.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Example Calculation Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFF334155)),
                                SizedBox(width: 6),
                                Text(
                                  'PRACTICAL EXAMPLE WITH LIVE RESTAURANT DATA',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Suppose an upcoming Friday has a ₱15,000 confirmed catering reservation, and Friday\'s 90-day baseline average is ₱7,945:',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Estimated Walk-In: ₱7,945 × ${_momentumFactor.toStringAsFixed(3)} = ${_currencyFormat.format(7945 * _momentumFactor)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '• Total Projected Sales: ₱15,000 + ${_currencyFormat.format(7945 * _momentumFactor)} = ${_currencyFormat.format(15000 + (7945 * _momentumFactor))}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF14332E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14332E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelPieSlice {
  final String channel;
  final double revenue;
  final Color color;

  _ChannelPieSlice(this.channel, this.revenue, this.color);
}
