import 'dart:math';

import 'dart:async';

import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:flutter/material.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeIn;

  late Timer? _realtimeTimer;

  final _supabase = Supabase.instance.client;

  late Stream<List<Map<String, dynamic>>> _ordersStream;

  late Stream<List<Map<String, dynamic>>> _advanceOrdersStream;

  late Stream<List<Map<String, dynamic>>> _inventoryStream;

  late Stream<List<Map<String, dynamic>>> _reservationsStream;

  // ── KPI data (now derived from streams) ──────────────────────────────────

  double _dailyRevenue = 0.0;
  int _totalOrders = 0;

  int _totalAdvanceOrders = 0;

  int _totalCustomers = 0;

  int _reservations = 0;

  int _pendingReservations = 0;

  List<double> _weeklyRevenue = List.filled(7, 0.0);
  List<Map<String, dynamic>> _lastOrders = [];
  List<Map<String, dynamic>> _lastAdvanceOrders = [];
  List<Map<String, dynamic>> _lastReservations = [];
  List<Map<String, dynamic>> _lastInventory = [];
  int _lastDay = DateTime.now().day;

  int _pendingOrders = 0;

  int _preparingOrders = 0;

  int _readyOrders = 0;

  int _outOfStock = 0;

  int _lowStock = 0;

  // ── Confirmed Events Analytics Data ───────────────────────────────

  final Map<String, int> _eventTypeDistribution = {};

  List<double> _monthlyEventTrends = List.filled(12, 0.0);

  // ignore: unused_field
  double _averageEventDuration = 0.0;

  int _totalConfirmedGuests = 0;

  // ignore: unused_field
  int _averageGuestsPerEvent = 0;

  List<Map<String, dynamic>> _topEventTypes = [];

  // ── Real-time Event Status Analytics ───────────────────────────────

  final List<Map<String, dynamic>> _upcomingEvents = [];

  final List<Map<String, dynamic>> _ongoingEvents = [];

  final List<Map<String, dynamic>> _completedEventsToday = [];

  Map<String, dynamic> _nextEvent = {};

  String _nextEventCountdown = '';

  // ignore: unused_field
  double _venueUtilizationRate = 0.0;

  // ignore: unused_field
  int _totalExpectedGuestsToday = 0;

  // ignore: unused_field
  int _currentGuestsOnSite = 0;

  // ignore: unused_field
  double _estimatedRevenueToday = 0.0;

  // Recent activity (now derived from streams)

  List<_ActivityItem> _recentActivity = [];
  int _activityCurrentPage = 1;
  static const int _activityItemsPerPage = 10;

  // ignore: unused_field
  DateTime? _lastUpdated;

  int _previousOrderCount = 0;

  bool? _showNewOrderNotification;

  String _newOrderAmount = '';

  // ── Real-time event conflict detection ───────────────────────────────

  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

  final List<String> _conflictDates = [];

  // ── Real-time reservation tracking ───────────────────────────────

  int _previousReservationCount = 0;

  bool? _showNewReservationNotification;

  String _newReservationInfo = '';

  // ── Real-time advance order tracking ───────────────────────────────

  int _previousAdvanceOrderCount = 0;

  bool? _showNewAdvanceOrderNotification;

  String _newAdvanceOrderInfo = '';

  // ── UI State Variables ───────────────────────────────────────────────

  DateTime? _focusedMonth;

  String _selectedPeriod = 'Weekly'; // New period selector state
  final FocusNode _dashboardPeriodFocusNode = FocusNode(canRequestFocus: false);

  final String _selectedYear = '2026'; // New year selector state

  int _schedulePage = 0;

  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();

    // Initialize state variables

    _showNewOrderNotification = false;

    _showNewReservationNotification = false;

    _showNewAdvanceOrderNotification = false;

    _focusedMonth = DateTime.now();

    // Enhanced real-time streams with immediate updates

    _ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (events) => events.map((order) {
            // Ensure all order data is properly loaded

            return {
              ...order,

              'total_amount': order['total_amount'] ?? 0.0,

              'created_at':
                  order['created_at']?.toString() ??
                  DateTime.now().toUtc().toIso8601String(),

              'customer_name': order['customer_name'] ?? 'Guest',

              'transaction_id': order['transaction_id'] ?? order['id'],
            };
          }).toList(),
        );

    _advanceOrdersStream = _supabase
        .from('advance_orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    _inventoryStream = _supabase.from('inventory').stream(primaryKey: ['id']);

    _reservationsStream = _supabase
        .from('reservations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 700),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    // Initialize real-time timer for countdown updates

    _realtimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateRealtimeData();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _realtimeTimer?.cancel();
    _dashboardPeriodFocusNode.dispose();
    super.dispose();
  }

  void _processData(
    List<Map<String, dynamic>> allOrders,

    List<Map<String, dynamic>> allAdvanceOrders,

    List<Map<String, dynamic>> allInventory,

    List<Map<String, dynamic>> allReservations,
  ) {
    _lastOrders = allOrders;
    _lastAdvanceOrders = allAdvanceOrders;
    _lastReservations = allReservations;

    // Check for new orders (real-time detection)

    final currentOrderCount = allOrders.length;

    if (_previousOrderCount > 0 && currentOrderCount > _previousOrderCount) {
      // New order detected!

      final newOrders = allOrders
          .take(currentOrderCount - _previousOrderCount)
          .toList();

      for (var newOrder in newOrders) {
        final amount = (newOrder['total_amount'] as num?)?.toDouble() ?? 0.0;

        _newOrderAmount = '₱${amount.toStringAsFixed(2)}';

        _showNewOrderNotification = true;

        // Auto-hide notification after 3 seconds

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showNewOrderNotification = false;
            });
          }
        });
      }
    }

    _previousOrderCount = currentOrderCount;

    // Check for new reservations (real-time detection)

    final currentReservationCount = allReservations.length;

    if (_previousReservationCount > 0 &&
        currentReservationCount > _previousReservationCount) {
      // New reservation detected!

      final newReservations = allReservations
          .take(currentReservationCount - _previousReservationCount)
          .toList();

      for (var newReservation in newReservations) {
        final customerName = newReservation['customer_name'] ?? 'Guest';

        final eventType = newReservation['event_type'] ?? 'Event';

        final eventDate = newReservation['event_date'] ?? 'Unknown';

        final startTime = newReservation['start_time'] ?? 'Unknown';

        _newReservationInfo =
            '$customerName booked $eventType on $eventDate at $startTime';

        _showNewReservationNotification = true;

        // Auto-hide notification after 5 seconds

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showNewReservationNotification = false;
            });
          }
        });
      }
    }

    _previousReservationCount = currentReservationCount;

    // Check for new advance orders (real-time detection)

    final currentAdvanceOrderCount = allAdvanceOrders.length;

    if (_previousAdvanceOrderCount > 0 &&
        currentAdvanceOrderCount > _previousAdvanceOrderCount) {
      // New advance order detected!

      final newAdvanceOrders = allAdvanceOrders
          .take(currentAdvanceOrderCount - _previousAdvanceOrderCount)
          .toList();

      for (var newAdvanceOrder in newAdvanceOrders) {
        final customerName = newAdvanceOrder['customer_name'] ?? 'Guest';

        final orderType = newAdvanceOrder['order_type'] ?? 'Unknown';

        _newAdvanceOrderInfo =
            '$customerName - $orderType';

        _showNewAdvanceOrderNotification = true;

        // Auto-hide notification after 4 seconds

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showNewAdvanceOrderNotification = false;
            });
          }
        });
      }
    }

    _previousAdvanceOrderCount = currentAdvanceOrderCount;

    // Process events for conflict detection

    _processEventConflicts(allReservations);

    // KPI Data

    final now = DateTime.now();

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Get ALL orders and advance orders for today (comprehensive daily revenue)

    final todayOrders = allOrders.where((o) {
      final createdAt = o['created_at']?.toString() ?? '';

      return createdAt.startsWith(todayStr);
    }).toList();

    final paidAdvanceOrders = allAdvanceOrders.where((o) {
      final isPaid =
          o['payment_status'] == 'paid' || o['payment_status'] == 'fully_paid';

      // Count ALL paid advance orders regardless of date

      return isPaid;
    }).toList();

    // Also get today's paid advance orders for revenue calculation

    final todayPaidAdvanceOrders = allAdvanceOrders.where((o) {
      final orderDate = o['order_date']?.toString() ?? '';

      final isPaid =
          o['payment_status'] == 'paid' || o['payment_status'] == 'fully_paid';

      // Only count if scheduled for today AND paid (for revenue)

      return orderDate == todayStr && isPaid;
    }).toList();

    // Calculate total daily revenue from ALL orders today

    final regularRevenue = todayOrders.fold(0.0, (sum, o) {
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;

      return sum + amount;
    });

    final advanceRevenue = todayPaidAdvanceOrders.fold(0.0, (sum, o) {
      final amount = (o['total_price'] as num?)?.toDouble() ?? 0.0;

      return sum + amount;
    });

    print('DEBUG: Today regular orders count: ${todayOrders.length}');

    print('DEBUG: Today regular revenue: ₱${regularRevenue}');

    print(
      'DEBUG: Today advance orders count: ${todayPaidAdvanceOrders.length}',
    );

    print(
      'DEBUG: Today advance revenue (tracked in Sales Report): ₱${advanceRevenue}',
    );

    // Admin Dashboard: Regular POS / Walk-in Orders Only
    // (Multi-channel breakdown for Advance & Events is in Sales Report)
    _dailyRevenue = regularRevenue;
    _totalOrders = todayOrders.length;
    _totalAdvanceOrders = paidAdvanceOrders.length;

    // Count guest count (pax) from today's regular orders
    final regularCustomers = todayOrders.fold<int>(
      0,
      (sum, o) => sum + ((o['number_of_guests'] as num?)?.toInt() ?? 1),
    );

    _totalCustomers = regularCustomers;

    // Reservations (Events) - Count active unarchived confirmed and pending reservations
    final unarchivedReservations = allReservations
        .where((r) => r['is_archived'] != true)
        .toList();

    final confirmedReservations = unarchivedReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == 'confirmed';
    }).toList();

    _reservations = confirmedReservations.length;

    final pendingReservations = unarchivedReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == 'pending';
    }).toList();

    _pendingReservations = pendingReservations.length;

    // Revenue Chart: Regular Orders only
    _weeklyRevenue = _processChartData(allOrders);

    // Kitchen Status Counts (Real-time from today's orders)

    final pendingRegular = todayOrders
        .where(
          (o) => (o['kitchen_status']?.toString() ?? 'Pending') == 'Pending',
        )
        .length;

    final pendingAdvance = todayPaidAdvanceOrders
        .where(
          (o) =>
              (o['status']?.toString().toLowerCase() ?? 'pending') == 'pending',
        )
        .length;

    _pendingOrders = pendingRegular + pendingAdvance;

    final preparingRegular = todayOrders
        .where((o) => (o['kitchen_status']?.toString() ?? '') == 'Preparing')
        .length;

    final preparingAdvance = todayPaidAdvanceOrders
        .where(
          (o) => (o['status']?.toString().toLowerCase() ?? '') == 'preparing',
        )
        .length;

    _preparingOrders = preparingRegular + preparingAdvance;

    final readyRegular = todayOrders
        .where((o) => (o['kitchen_status']?.toString() ?? '') == 'Ready')
        .length;

    final readyAdvance = todayPaidAdvanceOrders
        .where((o) => (o['status']?.toString().toLowerCase() ?? '') == 'ready')
        .length;

    _readyOrders = readyRegular + readyAdvance;

    // Inventory Alerts (Real-time)

    _outOfStock = allInventory
        .where((i) => ((i['quantity'] as num?)?.toInt() ?? 0) == 0)
        .length;

    _lowStock = allInventory.where((i) {
      final q = (i['quantity'] as num?)?.toInt() ?? 0;

      return q > 0 && q < 10;
    }).length;
    _lastUpdated = DateTime.now();

    // Update Recent Activity

    _updateActivity(todayOrders, allInventory, allReservations, allAdvanceOrders);

    // Process Confirmed Events Analytics

    _processConfirmedEventsAnalytics(allReservations);

    // Process Real-time Event Status

    _processRealtimeEventStatus(allReservations);
  }

  void _processConfirmedEventsAnalytics(
    List<Map<String, dynamic>> allReservations,
  ) {
    // Filter only active unarchived confirmed reservations
    final confirmedReservations = allReservations.where((r) {
      if (r['is_archived'] == true) return false;
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == 'confirmed';
    }).toList();

    if (confirmedReservations.isEmpty) {
      _eventTypeDistribution.clear();

      _monthlyEventTrends = List.filled(12, 0.0);

      _averageEventDuration = 0.0;

      _totalConfirmedGuests = 0;

      _averageGuestsPerEvent = 0;

      _topEventTypes = [];

      return;
    }

    // 2. Monthly Event Trends (current year)

    final now = DateTime.now();

    _monthlyEventTrends = List.filled(12, 0.0);

    for (var reservation in confirmedReservations) {
      final eventDate = DateTime.tryParse(
        reservation['event_date']?.toString() ?? '',
      );

      if (eventDate != null && eventDate.year == now.year) {
        final monthIndex = eventDate.month - 1; // 0 = Jan, 11 = Dec

        _monthlyEventTrends[monthIndex] = _monthlyEventTrends[monthIndex] + 1.0;
      }
    }

    // 1. Event Type Distribution (current year only for consistency)

    _eventTypeDistribution.clear();

    for (var reservation in confirmedReservations) {
      final eventDate = DateTime.tryParse(
        reservation['event_date']?.toString() ?? '',
      );

      if (eventDate != null && eventDate.year == now.year) {
        final eventType = reservation['event_type']?.toString() ?? 'Unknown';

        _eventTypeDistribution[eventType] =
            (_eventTypeDistribution[eventType] ?? 0) + 1;
      }
    }

    // 3. Average Event Duration

    double totalDuration = 0.0;

    int validDurations = 0;

    for (var reservation in confirmedReservations) {
      final duration = (reservation['duration_hours'] as num?)?.toDouble();

      if (duration != null && duration > 0) {
        totalDuration += duration;

        validDurations++;
      }
    }

    _averageEventDuration = validDurations > 0
        ? totalDuration / validDurations
        : 0.0;

    // 4. Guest Count Analytics

    _totalConfirmedGuests = 0;

    for (var reservation in confirmedReservations) {
      final guests = (reservation['number_of_guests'] as num?)?.toInt() ?? 0;

      _totalConfirmedGuests += guests;
    }

    _averageGuestsPerEvent = confirmedReservations.isNotEmpty
        ? (_totalConfirmedGuests / confirmedReservations.length).round()
        : 0;

    // 5. Top Event Types (sorted by count)

    _topEventTypes =
        _eventTypeDistribution.entries
            .map(
              (entry) => {
                'event_type': entry.key,

                'count': entry.value,

                'percentage': _eventTypeDistribution.isNotEmpty
                    ? ((entry.value /
                                  _eventTypeDistribution.values.reduce(
                                    (a, b) => a + b,
                                  )) *
                              100)
                          .toStringAsFixed(1)
                    : '0.0',
              },
            )
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int))
          ..take(5); // Top 5 event types
  }

  void _processRealtimeEventStatus(List<Map<String, dynamic>> allReservations) {
    final now = DateTime.now();

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Filter confirmed reservations

    final confirmedReservations = allReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();

      return status == 'confirmed';
    }).toList();

    // Clear previous lists

    _upcomingEvents.clear();

    _ongoingEvents.clear();

    _completedEventsToday.clear();

    _nextEvent = {};

    _nextEventCountdown = '';

    _totalExpectedGuestsToday = 0;

    _currentGuestsOnSite = 0;

    _estimatedRevenueToday = 0.0;

    // Process each confirmed reservation

    for (var reservation in confirmedReservations) {
      final eventDate = reservation['event_date']?.toString();

      final startTime = reservation['start_time']?.toString();

      final duration =
          (reservation['duration_hours'] as num?)?.toDouble() ?? 4.0;

      final guests = (reservation['number_of_guests'] as num?)?.toInt() ?? 0;

      if (eventDate != null && startTime != null) {
        DateTime eventStart;

        DateTime eventEnd;

        try {
          // Parse start time

          if (startTime.toUpperCase().contains('AM') ||
              startTime.toUpperCase().contains('PM')) {
            DateTime parsedTime = DateFormat.jm().parse(startTime.trim());

            final parsedDate = DateTime.parse(eventDate);

            eventStart = DateTime(
              parsedDate.year,

              parsedDate.month,

              parsedDate.day,

              parsedTime.hour,

              parsedTime.minute,
            );
          } else {
            String timeStr = startTime;

            if (timeStr.length == 5) timeStr = '$timeStr:00';

            eventStart = DateTime.parse('${eventDate}T$timeStr');
          }

          eventEnd = eventStart.add(Duration(hours: duration.toInt()));

          // Add enhanced data to reservation

          final enhancedReservation = {
            ...reservation,

            'event_start': eventStart,

            'event_end': eventEnd,

            'time_until_start': eventStart.difference(now),

            'time_until_end': eventEnd.difference(now),
          };

          // Categorize events based on current time

          if (now.isBefore(eventStart)) {
            // Upcoming event

            _upcomingEvents.add(enhancedReservation);

            _totalExpectedGuestsToday += guests;

            // Track next event (closest upcoming)

            if (_nextEvent.isEmpty ||
                eventStart.isBefore(_nextEvent['event_start'] as DateTime)) {
              _nextEvent = enhancedReservation;
            }
          } else if (now.isAfter(eventStart) && now.isBefore(eventEnd)) {
            // Ongoing event

            _ongoingEvents.add(enhancedReservation);

            _currentGuestsOnSite += guests;
          } else if (now.isAfter(eventEnd) && eventDate == todayStr) {
            // Completed event today

            _completedEventsToday.add(enhancedReservation);
          }

          // Calculate estimated revenue

          _estimatedRevenueToday += guests * 500.0;
        } catch (e) {
          // If parsing fails, skip this reservation

          continue;
        }
      }
    }

    // Sort upcoming events by start time

    _upcomingEvents.sort((a, b) {
      final startA = a['event_start'] as DateTime?;

      final startB = b['event_start'] as DateTime?;

      if (startA == null || startB == null) return 0;

      return startA.compareTo(startB);
    });

    // Calculate venue utilization rate

    final totalVenueHours =
        12; // Assuming 12 operational hours (10 AM to 10 PM)

    double totalBookedHours = 0.0;

    for (var event in _ongoingEvents) {
      final start = event['event_start'] as DateTime?;

      final end = event['event_end'] as DateTime?;

      if (start != null && end != null) {
        // Calculate overlap with today's operational hours

        final dayStart = DateTime(now.year, now.month, now.day, 10, 0);

        final dayEnd = DateTime(now.year, now.month, now.day, 22, 0);

        final overlapStart = start.isAfter(dayStart) ? start : dayStart;

        final overlapEnd = end.isBefore(dayEnd) ? end : dayEnd;

        if (overlapEnd.isAfter(overlapStart)) {
          totalBookedHours += overlapEnd.difference(overlapStart).inHours;
        }
      }
    }

    _venueUtilizationRate = totalVenueHours > 0
        ? (totalBookedHours / totalVenueHours) * 100
        : 0.0;

    // Update countdown for next event

    _updateNextEventCountdown();
  }

  void _updateRealtimeData() {
    // This method is called every second by the timer
    final now = DateTime.now();

    // Auto-refresh daily data when day rolls over at midnight
    if (now.day != _lastDay) {
      _lastDay = now.day;
      if (_lastOrders.isNotEmpty || _lastAdvanceOrders.isNotEmpty || _lastReservations.isNotEmpty) {
        _processData(_lastOrders, _lastAdvanceOrders, _lastInventory, _lastReservations);
      }
    }

    _updateNextEventCountdown();

    // Recalculate current guests on site (in case events ended)
    _currentGuestsOnSite = 0;

    for (var event in _ongoingEvents) {
      final eventEnd = event['event_end'] as DateTime?;

      if (eventEnd != null && now.isBefore(eventEnd)) {
        final guests = (event['number_of_guests'] as num?)?.toInt() ?? 0;

        _currentGuestsOnSite += guests;
      }
    }

    // Move events from ongoing to completed if they ended

    _ongoingEvents.removeWhere((event) {
      final eventEnd = event['event_end'] as DateTime?;

      if (eventEnd != null && now.isAfter(eventEnd)) {
        final eventDate = event['event_date']?.toString();

        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        if (eventDate == todayStr) {
          _completedEventsToday.add(event);
        }

        return true;
      }

      return false;
    });

    // Move events from upcoming to ongoing if they started

    _upcomingEvents.removeWhere((event) {
      final eventStart = event['event_start'] as DateTime?;

      if (eventStart != null && now.isAfter(eventStart)) {
        final eventEnd = event['event_end'] as DateTime?;

        if (eventEnd != null && now.isBefore(eventEnd)) {
          _ongoingEvents.add(event);

          return true;
        }
      }

      return false;
    });
  }

  void _updateNextEventCountdown() {
    if (_nextEvent.isNotEmpty) {
      final eventStart = _nextEvent['event_start'] as DateTime?;

      if (eventStart != null) {
        final now = DateTime.now();

        final difference = eventStart.difference(now);

        if (difference.inSeconds > 0) {
          if (difference.inDays > 0) {
            _nextEventCountdown =
                '${difference.inDays}d ${difference.inHours % 24}h ${difference.inMinutes % 60}m';
          } else if (difference.inHours > 0) {
            _nextEventCountdown =
                '${difference.inHours}h ${difference.inMinutes % 60}m';
          } else if (difference.inMinutes > 0) {
            _nextEventCountdown =
                '${difference.inMinutes}m ${difference.inSeconds % 60}s';
          } else {
            _nextEventCountdown = '${difference.inSeconds}s';
          }
        } else {
          _nextEventCountdown = 'Starting now!';
        }
      } else {
        _nextEventCountdown = '';
      }
    } else {
      _nextEventCountdown = 'No upcoming events';
    }
  }

  void _processEventConflicts(List<Map<String, dynamic>> allReservations) {
    // Clear previous conflicts

    _eventsByDate.clear();

    _conflictDates.clear();

    // Group confirmed reservations by date and time

    Map<String, List<Map<String, dynamic>>> eventsByDateTime = {};

    for (var reservation in allReservations) {
      if (reservation['status'] == 'confirmed' ||
          reservation['status'] == 'pending') {
        final eventDate = reservation['event_date']?.toString();

        if (eventDate != null) {
          // Parse start time and calculate end time

          DateTime eventStart;

          DateTime eventEnd;

          try {
            final startTime =
                reservation['start_time']?.toString() ?? '10:00 AM';

            final durationHours =
                (reservation['duration_hours'] as num?)?.toDouble() ?? 4.0;

            // Parse start time

            if (startTime.toUpperCase().contains('AM') ||
                startTime.toUpperCase().contains('PM')) {
              DateTime parsedTime = DateFormat.jm().parse(startTime.trim());

              final parsedDate = DateTime.parse(eventDate);

              eventStart = DateTime(
                parsedDate.year,

                parsedDate.month,

                parsedDate.day,

                parsedTime.hour,

                parsedTime.minute,
              );
            } else {
              String timeStr = startTime;

              if (timeStr.length == 5) timeStr = '$timeStr:00';

              eventStart = DateTime.parse('${eventDate}T$timeStr');
            }

            // Calculate end time

            eventEnd = eventStart.add(Duration(hours: durationHours.toInt()));

            // Create time slot key for grouping

            final timeSlotKey = '${eventDate}_${eventStart.hour}';

            if (!eventsByDateTime.containsKey(timeSlotKey)) {
              eventsByDateTime[timeSlotKey] = [];
            }

            eventsByDateTime[timeSlotKey]!.add({
              ...reservation,

              'event_start': eventStart,

              'event_end': eventEnd,
            });

            // Also add to original _eventsByDate for display

            if (!_eventsByDate.containsKey(eventDate)) {
              _eventsByDate[eventDate] = [];
            }

            _eventsByDate[eventDate]!.add({
              ...reservation,

              'event_start': eventStart,

              'event_end': eventEnd,
            });
          } catch (e) {
            // If parsing fails, add to original date grouping as fallback

            if (!_eventsByDate.containsKey(eventDate)) {
              _eventsByDate[eventDate] = [];
            }

            _eventsByDate[eventDate]!.add(reservation);
          }
        }
      }
    }

    // Check for time-based conflicts with priority logic

    for (var dateKey in eventsByDateTime.keys) {
      final events = eventsByDateTime[dateKey];

      if (events != null && events.length > 1) {
        // Sort events by start time to establish priority

        events.sort((a, b) {
          final startA = a['event_start'] as DateTime?;

          final startB = b['event_start'] as DateTime?;

          if (startA == null || startB == null) return 0;

          return startA.compareTo(startB);
        });

        // Check for overlapping time slots with priority

        for (int i = 0; i < events.length; i++) {
          for (int j = i + 1; j < events.length; j++) {
            final event1 = events[i]; // Earlier event (higher priority)

            final event2 = events[j]; // Later event (lower priority)

            if (event1['event_start'] != null &&
                event2['event_start'] != null) {
              final start1 = event1['event_start'] as DateTime;

              final end1 = event1['event_end'] as DateTime;

              final start2 = event2['event_start'] as DateTime;

              final end2 = event2['event_end'] as DateTime;

              // Check if time slots overlap

              if ((start1.isBefore(end2) && end1.isAfter(start2)) ||
                  (start2.isBefore(end1) && end2.isAfter(start1)) ||
                  (start1.isAtSameMomentAs(start2))) {
                // Conflict detected - add date to conflict list

                final dateStr = DateFormat('yyyy-MM-dd').format(start1);

                if (!_conflictDates.contains(dateStr)) {
                  _conflictDates.add(dateStr);
                }

                break;
              }
            }
          }
        }
      }
    }
  }

  List<String> getChartLabels() {
    if (_selectedPeriod == 'Daily') {
      // Extended business hours: 8:00 AM to 11:00 PM (8:00 to 23:00)
      return [
        '08:00', '09:00', '10:00', '11:00', '12:00',
        '13:00', '14:00', '15:00', '16:00', '17:00',
        '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
      ];
    } else if (_selectedPeriod == 'Weekly') {
      return [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
    } else if (_selectedPeriod == 'Monthly') {
      return [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
    } else {
      // Annual - 2016 to current year
      final currentYear = DateTime.now().year;
      return List.generate(
        currentYear - 2016 + 1,
        (index) => (2016 + index).toString(),
      );
    }
  }

  List<double> _processChartData(
    List<Map<String, dynamic>> orders, {
    List<Map<String, dynamic>>? advanceOrders,
    List<Map<String, dynamic>>? reservations,
  }) {
    final now = DateTime.now();
    Map<int, double> periodData = {};

    // Helper to process a list of orders/reservations
    void processList(
      List<Map<String, dynamic>> list, {
      required bool isAdvance,
      required bool isReservation,
    }) {
      for (var item in list) {
        if (isReservation && item['is_archived'] == true) continue;

        final dateStr = isReservation
            ? (item['payment_date'] ?? item['event_date'] ?? item['created_at'])
            : (isAdvance ? (item['order_date'] ?? item['created_at']) : item['created_at']);

        // Convert UTC timestamp from Supabase to Local Device Time
        final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
        if (date == null) continue;

        if (isAdvance) {
          final isPaid =
              item['payment_status'] == 'paid' ||
              item['payment_status'] == 'fully_paid';
          if (!isPaid) continue;
        } else if (isReservation) {
          final paymentStatus = item['payment_status']?.toString().toLowerCase() ?? '';
          final status = item['status']?.toString().toLowerCase() ?? '';
          final isPaid =
              paymentStatus == 'paid' ||
              paymentStatus == 'fully_paid' ||
              paymentStatus == 'deposit_paid' ||
              status == 'confirmed' ||
              status == 'completed';
          if (!isPaid) continue;
        }

        double amount = 0.0;
        if (isReservation) {
          final paymentStatus = item['payment_status']?.toString().toLowerCase() ?? '';
          if (paymentStatus == 'deposit_paid') {
            amount = (item['deposit_amount'] as num?)?.toDouble() ??
                ((item['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
          } else {
            amount = (item['total_price'] as num?)?.toDouble() ?? 0.0;
          }
        } else {
          amount = isAdvance
              ? (item['total_price'] as num?)?.toDouble() ?? 0.0
              : (item['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Apply period-specific filtering
        switch (_selectedPeriod) {
          case 'Daily':
            if (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day &&
                date.hour >= 8 &&
                date.hour <= 23) {
              // Map hour to 0-based index within business hours (08:00–23:00)
              final key = date.hour - 8;
              periodData[key] = (periodData[key] ?? 0) + amount;
            }
            break;

          case 'Weekly':
            final dailyDiff = now.difference(date).inDays;
            if (dailyDiff >= 0 &&
                dailyDiff < 7 &&
                date.year.toString() == _selectedYear) {
              final key = date.weekday - 1;
              periodData[key] = (periodData[key] ?? 0) + amount;
            }
            break;

          case 'Monthly':
            if (date.year.toString() == _selectedYear) {
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
    }

    // Process regular orders
    processList(orders, isAdvance: false, isReservation: false);

    // Also include paid advance orders if provided
    if (advanceOrders != null && advanceOrders.isNotEmpty) {
      processList(advanceOrders, isAdvance: true, isReservation: false);
    }

    // Also include event reservations if provided
    if (reservations != null && reservations.isNotEmpty) {
      processList(reservations, isAdvance: false, isReservation: true);
    }

    // Convert to list based on selected period
    if (_selectedPeriod == 'Daily') {
      return List.generate(16, (i) => periodData[i] ?? 0.0); // 16 business hours: 08:00-23:00
    } else if (_selectedPeriod == 'Weekly') {
      return List.generate(7, (i) => periodData[i] ?? 0.0);
    } else if (_selectedPeriod == 'Monthly') {
      return List.generate(12, (i) => periodData[i] ?? 0.0);
    } else {
      final currentYear = now.year;
      final yearRange = currentYear - 2016 + 1;
      return List.generate(yearRange, (i) => periodData[i] ?? 0.0);
    }
  }

  void _updateActivity(
    List<Map<String, dynamic>> recentOrders,

    List<Map<String, dynamic>> inventory,

    List<Map<String, dynamic>> reservations,

    List<Map<String, dynamic>> advanceOrders,
  ) {
    List<_ActivityItem> activities = [];

    // Latest 5 POS Orders (for main dashboard)
    for (var i = 0; i < min(5, recentOrders.length); i++) {
      final o = recentOrders[i];

      final time = DateTime.tryParse(o['created_at'] ?? '');
      final timeStr = time != null
          ? DateFormat('HH:mm').format(time)
          : 'Just now';

      final kitchenStatus = (o['kitchen_status']?.toString() ?? '').toLowerCase();
      final orderStatus = (o['order_status']?.toString() ?? o['status']?.toString() ?? '').toLowerCase();

      String statusTitle;
      Color statusColor;
      IconData statusIcon;

      if (kitchenStatus == 'preparing' || orderStatus == 'preparing') {
        statusTitle = 'Order #${o['transaction_id'] ?? o['id']} In Prep';
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.local_fire_department_rounded;
      } else if (kitchenStatus == 'ready' || orderStatus == 'ready') {
        statusTitle = 'Order #${o['transaction_id'] ?? o['id']} Ready';
        statusColor = AppTheme.infoBlue;
        statusIcon = Icons.check_circle_outline_rounded;
      } else if (kitchenStatus == 'completed' || kitchenStatus == 'served' || orderStatus == 'completed' || orderStatus == 'paid') {
        statusTitle = 'Order #${o['transaction_id'] ?? o['id']} Completed';
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
      } else if (orderStatus == 'cancelled') {
        statusTitle = 'Order #${o['transaction_id'] ?? o['id']} Cancelled';
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
      } else {
        // Pending / New Order
        statusTitle = 'Order #${o['transaction_id'] ?? o['id']} Placed';
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.receipt_long_rounded;
      }

      activities.add(
        _ActivityItem(
          icon: statusIcon,
          color: statusColor,
          title: statusTitle,
          subtitle: '${o['customer_name'] ?? 'Guest'} · ₱${o['total_amount']}',
          time: timeStr,
        ),
      );
    }

    // Latest 3 Advance Orders (for main dashboard)
    for (var i = 0; i < min(3, advanceOrders.length); i++) {
      final ao = advanceOrders[i];

      final time = DateTime.tryParse(ao['created_at'] ?? '');
      final timeStr = time != null
          ? DateFormat('HH:mm').format(time)
          : 'Just now';

      final status = (ao['status']?.toString() ?? 'pending').toLowerCase();
      final paymentStatus = (ao['payment_status']?.toString() ?? 'unpaid').toLowerCase();
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'fully_paid';

      String statusTitle;
      Color statusColor;
      IconData statusIcon;

      if (status == 'completed') {
        statusTitle = 'Advance Order #${ao['id']} Completed';
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
      } else if (status == 'preparing') {
        statusTitle = 'Advance Order #${ao['id']} In Prep';
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.local_fire_department_rounded;
      } else if (status == 'ready') {
        statusTitle = 'Advance Order #${ao['id']} Ready';
        statusColor = AppTheme.infoBlue;
        statusIcon = Icons.check_circle_outline_rounded;
      } else if (isPaid) {
        statusTitle = 'Advance Order #${ao['id']} Paid';
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.calendar_today_rounded;
      } else {
        statusTitle = 'New Advance Order #${ao['id']}';
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.pending_actions_rounded;
      }

      activities.add(
        _ActivityItem(
          icon: statusIcon,
          color: statusColor,
          title: statusTitle,
          subtitle: '${ao['customer_name'] ?? 'Guest'} · ₱${ao['total_price']} · ${ao['order_date'] ?? 'TBD'}',
          time: timeStr,
        ),
      );
    }

    // Latest 3 Reservations (for main dashboard)
    for (var i = 0; i < min(3, reservations.length); i++) {
      final r = reservations[i];

      final status = (r['status']?.toString() ?? 'pending').toLowerCase();
      final isConfirmed = status == 'confirmed';
      final isCancelled = status == 'cancelled' || status == 'rejected';

      activities.add(
        _ActivityItem(
          icon: isConfirmed
              ? Icons.check_circle_rounded
              : isCancelled
                  ? Icons.cancel_rounded
                  : Icons.event_available_rounded,
          color: isConfirmed
              ? AppTheme.successGreen
              : isCancelled
                  ? const Color(0xFFEF4444)
                  : AppTheme.infoBlue,
          title: isConfirmed
              ? 'Reservation Confirmed'
              : isCancelled
                  ? 'Reservation Cancelled'
                  : 'New Reservation',
          subtitle: '${r['customer_name']} · ${r['event_type']}',
          time: 'Just now',
        ),
      );
    }

    // Latest 2 Low Stock Alerts (for main dashboard)
    final lowStockItems = inventory
        .where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) < 10)
        .take(2)
        .toList();

    for (var item in lowStockItems) {
      activities.add(
        _ActivityItem(
          icon: Icons.inventory_2_rounded,
          color: AppTheme.warningOrange,
          title: 'Low Stock Alert',
          subtitle: '${item['name']} · ${item['quantity']} left',
          time: 'Now',
        ),
      );
    }

    _recentActivity = activities;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      color: AppTheme.adminMainBackground,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,

      builder: (context, orderSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _advanceOrdersStream,

          builder: (context, advanceSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _inventoryStream,

              builder: (context, invSnapshot) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _reservationsStream,

                  builder: (context, resSnapshot) {
                    final allOrders = orderSnapshot.data ?? [];

                    final allAdvanceOrders = advanceSnapshot.data ?? [];

                    final allInventory = invSnapshot.data ?? [];

                    final allReservations = resSnapshot.data ?? [];

                    _processData(
                      allOrders,

                      allAdvanceOrders,

                      allInventory,

                      allReservations,
                    );

                    return FadeTransition(
                      opacity: _fadeIn,
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: ResponsiveUtils.isMobile(context)
                                ? const EdgeInsets.all(14)
                                : const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Premium Header ─────────────────────────
                                _buildGreeting(context),
                                const SizedBox(height: 20),

                                // ── KPI Cards ─────────────────────────────
                                _buildSectionTitle(context, 'Today\'s Performance',
                                    icon: Icons.leaderboard_rounded,
                                    badge: DateFormat('d MMM').format(DateTime.now())),
                                const SizedBox(height: 12),
                                _buildKpiGrid(isDesktop || isTablet),
                                const SizedBox(height: 24),

                                // ── Main Analytics & Monitoring Sections ──────────────────
                                _buildSectionTitle(context, 'Gross Analytics',
                                    icon: Icons.show_chart_rounded),
                                const SizedBox(height: 12),
                                _buildRevenueChart(context),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Live Events Monitor',
                                    icon: Icons.event_available_rounded),
                                const SizedBox(height: 12),
                                _buildLiveEventsMonitor(context),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Venue Status',
                                    icon: Icons.storefront_rounded),
                                const SizedBox(height: 12),
                                _buildVenueStatus(context),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Event Analytics',
                                    icon: Icons.pie_chart_rounded),
                                const SizedBox(height: 12),
                                _buildConfirmedEventsAnalytics(context, isDesktop || isTablet),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Monthly Event Schedule',
                                    icon: Icons.calendar_month_rounded),
                                const SizedBox(height: 12),
                                _buildMonthlyOverview(context),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Operations Monitor',
                                    icon: Icons.assignment_rounded),
                                const SizedBox(height: 12),
                                _buildOperationsMonitor(context),
                                const SizedBox(height: 20),

                                _buildSectionTitle(context, 'Recent Activity',
                                    icon: Icons.history_rounded),
                                const SizedBox(height: 12),
                                _buildRecentActivity(context),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),

                          // Real-time notification overlay
                          if (_showNewOrderNotification ?? false)
                            Positioned(
                              top: 20,

                              right: 20,

                              child: _buildNewOrderNotification(),
                            ),

                          // New reservation notification overlay
                          if (_showNewReservationNotification ?? false)
                            Positioned(
                              top: 80,

                              right: 20,

                              child: _buildNewReservationNotification(),
                            ),

                          // New advance order notification overlay
                          if (_showNewAdvanceOrderNotification ?? false)
                            Positioned(
                              top: 140,

                              right: 20,

                              child: _buildNewAdvanceOrderNotification(),
                            ),
                        ],
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
    );
  }

  // ── Greeting & Header ──────────────────────────────────────────────────

  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final greetingIcon = hour < 12 ? '🌤️' : hour < 17 ? '☀️' : '🌙';
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14332E), Color(0xFF1B4942), Color(0xFF0F2923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(greetingIcon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      '$greeting, Administrator',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: AppTheme.successGreen, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text('● LIVE', style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(timeStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.restaurant_rounded, color: AppTheme.warmGold, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Yang Chow',
                style: TextStyle(color: AppTheme.warmGold.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              Text(
                'Admin Portal',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(BuildContext context, String title, {IconData? icon, String? badge}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.adminSidebarBackground.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon ?? Icons.dashboard_rounded, size: 15, color: AppTheme.adminSidebarBackground),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.adminPrimaryText,
            fontSize: 15,
            letterSpacing: -0.3,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.adminSidebarBackground.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.adminSidebarBackground)),
          ),
        ],
        const Spacer(),
        Text(
          DateFormat('MMM yyyy').format(DateTime.now()),
          style: const TextStyle(fontSize: 11, color: AppTheme.adminSecondaryText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── Clickable Section Title ─────────────────────────────────────────────────────────

  // ── KPI Grid ──────────────────────────────────────────────────────────────

  // ── Executive KPI Cards (Sales Report Style) ──────────────────────────────
  Widget _buildKpiGrid(bool isWide) {
    final pendingCount = _pendingOrders + _preparingOrders;
    final stockAlert = _outOfStock + _lowStock;

    final cards = [
      // 1. Featured Gross Revenue Card (Regular Walk-in Revenue)
      _buildFeaturedRevenueCard(_dailyRevenue),
      // 2. Walk-in Orders Volume
      _buildStandardKpiCard(
        title: 'Walk-in Orders',
        value: '$_totalOrders',
        unit: 'Orders',
        subtitle: pendingCount > 0 ? '$pendingCount pending' : 'All completed',
        icon: Icons.shopping_bag_outlined,
        accentColor: AppTheme.infoBlue,
        trend: pendingCount == 0 ? 'COMPLETED' : 'IN PROGRESS',
        isWarning: pendingCount > 0,
      ),
      // 3. Advance Bookings
      _buildStandardKpiCard(
        title: 'Advance Orders',
        value: '$_totalAdvanceOrders',
        unit: 'Bookings',
        subtitle: _totalAdvanceOrders > 0 ? 'Paid & active' : 'No active orders',
        icon: Icons.event_note_outlined,
        accentColor: const Color(0xFF6366F1),
        trend: _totalAdvanceOrders > 0 ? 'ACTIVE' : 'READY',
      ),
      // 4. Guests Served
      _buildStandardKpiCard(
        title: 'Guests Today',
        value: '$_totalCustomers',
        unit: 'Pax Served',
        subtitle: 'Dine-in & Walk-in',
        icon: Icons.people_outline_rounded,
        accentColor: const Color(0xFF8B5CF6),
        trend: _totalCustomers > 0 ? '+ACTIVE' : 'STANDBY',
      ),
      // 5. Confirmed Events / Stock Health
      _buildStandardKpiCard(
        title: 'Confirmed Events',
        value: '$_reservations',
        unit: 'Bookings',
        subtitle: _pendingReservations > 0
            ? '$_pendingReservations pending approval'
            : (stockAlert > 0 ? '$stockAlert stock alert' : 'Optimal operations'),
        icon: Icons.celebration_outlined,
        accentColor: _pendingReservations > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
        trend: _pendingReservations > 0 ? 'PENDING' : 'GOOD',
        isWarning: _pendingReservations > 0 || stockAlert > 0,
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

  Widget _buildFeaturedRevenueCard(double totalRevenue) {
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
                          'DAILY GROSS',
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
              _formatNumber(totalRevenue),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Regular Walk-in',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFFC7D6D3), fontWeight: FontWeight.w500),
                ),
                Text(
                  '$_totalOrders orders today',
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.warmGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
    required String trend,
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
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppTheme.adminSecondaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Revenue Chart ─────────────────────────────────────────────────────────

  Widget _buildRevenueChart(BuildContext context) {
    final dayLabels = getChartLabels();

    // Ensure data consistency
    final dataLength = _weeklyRevenue.length;
    final labelsLength = dayLabels.length;
    final chartLength = dataLength < labelsLength ? dataLength : labelsLength;

    final maxRevenue = _weeklyRevenue.isEmpty
        ? 0.0
        : _weeklyRevenue.reduce(max);

    final maxY = (maxRevenue == 0 ? 1000.0 : maxRevenue * 1.25)
        .clamp(1000.0, 10000000.0)
        .toDouble();

    final weeklyFull = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final weeklyShort = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dailyFull = [
      '8:00 AM','9:00 AM','10:00 AM','11:00 AM','12:00 PM',
      '1:00 PM','2:00 PM','3:00 PM','4:00 PM','5:00 PM',
      '6:00 PM','7:00 PM','8:00 PM','9:00 PM','10:00 PM','11:00 PM'
    ];
    final dailyShort = [
      '8AM','9AM','10AM','11AM','12PM',
      '1PM','2PM','3PM','4PM','5PM',
      '6PM','7PM','8PM','9PM','10PM','11PM'
    ];

    String bottomLabel(int i) {
      if (_selectedPeriod == 'Weekly') return i < weeklyShort.length ? weeklyShort[i] : 'D${i+1}';
      if (_selectedPeriod == 'Daily') return i < dailyShort.length ? dailyShort[i] : '${i+8}:00';
      return i < dayLabels.length ? dayLabels[i] : 'M${i+1}';
    }

    String tooltipLabel(int i) {
      if (_selectedPeriod == 'Weekly') return i < weeklyFull.length ? weeklyFull[i] : 'Day ${i+1}';
      if (_selectedPeriod == 'Daily') return i < dailyFull.length ? dailyFull[i] : '${i+8}:00';
      return i < dayLabels.length ? dayLabels[i] : 'Month ${i+1}';
    }

    final chartData = List.generate(chartLength, (i) {
      final val = i < _weeklyRevenue.length ? _weeklyRevenue[i] : 0.0;
      return _RevenueData(bottomLabel(i), val);
    });

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.adminPrimaryAccent, AppTheme.adminChatButton],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gross Analytics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedPeriod == 'Weekly'
                          ? 'This week\'s gross overview'
                          : _selectedPeriod == 'Daily'
                              ? 'Today\'s hourly gross overview'
                              : _selectedPeriod == 'Monthly'
                                  ? 'Monthly gross overview'
                                  : 'Annual gross overview',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _periodSelector(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Summary Stats Row ──────────────────────────────────────────────
          _buildChartSummaryRow(chartData),

          const SizedBox(height: 16),

          // ── Divider ───────────────────────────────────────────────────────
          Container(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 16),

          // ── Main Chart ────────────────────────────────────────────────────
          SizedBox(
            height: 270,
            child: chartData.every((d) => d.value == 0)
                ? _buildChartEmptyState()
                : _buildSfChart(chartData, maxY, tooltipLabel),
          ),

          const SizedBox(height: 12),

          // ── Legend ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Total Revenue',
                style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Container(
                width: 9, height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9A441),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Peak Point',
                style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              const Text(
                '• Regular Walk-in / POS Orders',
                style: TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSummaryRow(List<_RevenueData> chartData) {
    final total = chartData.fold<double>(0, (s, d) => s + d.value);
    final peak = chartData.isEmpty ? null : chartData.reduce((a, b) => a.value >= b.value ? a : b);
    final fmt = NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH');
    final fmtFull = NumberFormat.simpleCurrency(name: '₱', locale: 'en_PH', decimalDigits: 2);
    final periodLabel = _selectedPeriod == 'Daily' ? 'Hour'
        : _selectedPeriod == 'Weekly' ? 'Day'
        : _selectedPeriod == 'Monthly' ? 'Month' : 'Year';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChartStat(
            icon: Icons.paid_rounded,
            color: const Color(0xFF14332E),
            label: 'Total Revenue',
            value: fmtFull.format(total),
          ),
          Container(width: 1, height: 28, color: AppTheme.cardBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
          _buildChartStat(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFFD9A441),
            label: 'Peak $periodLabel',
            value: (peak != null && peak.value > 0)
                ? '${peak.label}  •  ${fmt.format(peak.value)}'
                : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildChartStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkGrey,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_rounded, color: AppTheme.mediumGrey, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Revenue Data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkGrey),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedPeriod == 'Daily'
                ? 'No transactions recorded today'
                : _selectedPeriod == 'Weekly'
                    ? 'No transactions in the past 7 days'
                    : 'No data for the selected period',
            style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildSfChart(List<_RevenueData> chartData, double maxY, String Function(int) tooltipLabel) {
    double peakVal = 0;
    for (final d in chartData) {
      if (d.value > peakVal) peakVal = d.value;
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      plotAreaBackgroundColor: Colors.transparent,
      margin: const EdgeInsets.only(left: 0, right: 8, top: 8, bottom: 0),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        shouldAlwaysShow: false,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final _RevenueData item = data;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
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
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: Color(0xFFD9A441), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tooltipLabel(pointIndex),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  NumberFormat.simpleCurrency(name: '₱', locale: 'en_PH', decimalDigits: 2).format(item.value),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                if (item.value == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('No transactions', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                  ),
              ],
            ),
          );
        },
      ),
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: CrosshairLineType.vertical,
        lineColor: AppTheme.mediumGrey.withValues(alpha: 0.3),
        lineWidth: 1,
        lineDashArray: const [4, 4],
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 1, color: AppTheme.cardBorder),
        labelStyle: const TextStyle(color: AppTheme.mediumGrey, fontSize: 9.5, fontWeight: FontWeight.w600),
        labelRotation: _selectedPeriod == 'Daily' ? -35 : 0,
        majorTickLines: const MajorTickLines(size: 0),
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: const TextStyle(color: AppTheme.mediumGrey, fontSize: 9.5, fontWeight: FontWeight.w600),
        numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          dashArray: const [4, 4],
        ),
        maximum: maxY,
        minimum: 0,
        desiredIntervals: 5,
      ),
      series: <CartesianSeries<_RevenueData, String>>[
        // Gradient filled area
        SplineAreaSeries<_RevenueData, String>(
          dataSource: chartData,
          xValueMapper: (_RevenueData d, _) => d.label,
          yValueMapper: (_RevenueData d, _) => d.value,
          name: 'Revenue Area',
          enableTooltip: false,
          animationDuration: 900,
          splineType: SplineType.cardinal,
          cardinalSplineTension: 0.6,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF14332E).withValues(alpha: 0.20),
              const Color(0xFF14332E).withValues(alpha: 0.08),
              const Color(0xFF14332E).withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderWidth: 0,
          markerSettings: const MarkerSettings(isVisible: false),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
        // Main smooth line
        SplineSeries<_RevenueData, String>(
          dataSource: chartData,
          xValueMapper: (_RevenueData d, _) => d.label,
          yValueMapper: (_RevenueData d, _) => d.value,
          name: 'Revenue',
          enableTooltip: true,
          animationDuration: 1000,
          splineType: SplineType.cardinal,
          cardinalSplineTension: 0.6,
          color: const Color(0xFF14332E),
          width: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            width: 5,
            height: 5,
            color: Colors.white,
            borderColor: Color(0xFF14332E),
            borderWidth: 2,
          ),
          dataLabelSettings: DataLabelSettings(
            isVisible: peakVal > 0,
            labelAlignment: ChartDataLabelAlignment.top,
            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
              final _RevenueData item = data;
              if (item.value != peakVal || peakVal == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9A441),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 9, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH').format(item.value),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Venue Status ──────────────────────────────────────────────────────────

  Widget _buildVenueStatus(BuildContext context) {
    final venueStatus = _getVenueStatus();
    final isReserved = venueStatus['isReserved'] as bool;
    final statusText = venueStatus['statusText'] as String;
    final subtitleText = venueStatus['subtitleText'] as String;
    final statusColor = venueStatus['statusColor'] as Color;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isReserved ? Icons.event_busy_rounded : Icons.storefront_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Venue Operations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGrey,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Real-time dining hall & private reservation monitor',
                            style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Live Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(color: statusColor, size: 7),
                    const SizedBox(width: 6),
                    Text(
                      statusText == 'OPEN' ? 'OPEN FOR DINING' : statusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Next Event Countdown (If scheduled today)
          if (_nextEvent.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warmGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppTheme.warmGold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'NEXT SCHEDULED EVENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.warmGold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _getEventStatusColor(_nextEvent).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getEventStatusText(_nextEvent),
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _getEventStatusColor(_nextEvent)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_nextEvent['event_type']} • ${_nextEvent['customer_name']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'STARTS IN',
                          style: TextStyle(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _nextEventCountdown,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main Interactive Cockpit: Realistic Glowing Ring Gauge + Operational Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 750;

              final gaugeWidget = Container(
                width: isWide ? 260 : double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.05),
                      statusColor.withValues(alpha: 0.01),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Realistic Glowing Circle Gauge
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient glow background
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.18),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Dual-layer Ring Gauge
                          SfCircularChart(
                            margin: EdgeInsets.zero,
                            series: <CircularSeries<_PieData, String>>[
                              DoughnutSeries<_PieData, String>(
                                dataSource: [
                                  _PieData('Active', 100, statusColor),
                                ],
                                xValueMapper: (_PieData data, _) => data.x,
                                yValueMapper: (_PieData data, _) => data.y,
                                pointColorMapper: (_PieData data, _) => data.color,
                                innerRadius: '78%',
                                radius: '98%',
                                cornerStyle: CornerStyle.bothCurve,
                                startAngle: 270,
                                endAngle: 630,
                              ),
                            ],
                          ),
                          // Inner Core Status
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '● LIVE',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.darkGrey.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Operating Slot Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.mediumGrey),
                          const SizedBox(width: 4),
                          const Text(
                            '10:00 AM – 8:00 PM • Active',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.darkGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final metricsGrid = Column(
                children: [
                  _buildVenueMetricTile(
                    icon: Icons.table_restaurant_rounded,
                    accentColor: AppTheme.successGreen,
                    title: 'DINING HALL AVAILABILITY',
                    status: isReserved ? 'Temporarily Reserved' : '100% Available for Walk-ins',
                    detail: isReserved
                        ? 'Private function ongoing • Walk-in dining paused'
                        : 'Normal dining operations • No private event lockouts',
                    chipText: isReserved ? 'OCCUPIED' : 'OPTIMAL',
                  ),
                  const SizedBox(height: 10),
                  _buildVenueMetricTile(
                    icon: Icons.access_time_filled_rounded,
                    accentColor: AppTheme.infoBlue,
                    title: 'BUSINESS OPERATING SHIFT',
                    status: 'Standard Shift: 10:00 AM – 8:00 PM',
                    detail: 'Kitchen and bar stations active • Cashier & POS online',
                    chipText: 'ONLINE',
                  ),
                  const SizedBox(height: 10),
                  _buildVenueMetricTile(
                    icon: Icons.celebration_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    title: "TODAY'S EVENT SCHEDULE",
                    status: _nextEvent.isNotEmpty
                        ? '${_nextEvent['event_type']} (${_nextEvent['customer_name']})'
                        : 'No Private Events Today',
                    detail: _nextEvent.isNotEmpty
                        ? 'Booked slot: ${DateFormat('hh:mm a').format(_nextEvent['event_start'] ?? DateTime.now())} - ${DateFormat('hh:mm a').format(_nextEvent['event_end'] ?? DateTime.now())}'
                        : 'Entire dining area open for regular customers all day',
                    chipText: _nextEvent.isNotEmpty ? 'SCHEDULED' : 'CLEAR',
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gaugeWidget,
                    const SizedBox(width: 16),
                    Expanded(child: metricsGrid),
                  ],
                );
              }

              return Column(
                children: [
                  gaugeWidget,
                  const SizedBox(height: 14),
                  metricsGrid,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVenueMetricTile({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String status,
    required String detail,
    required String chipText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.adminSecondaryText,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chipText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.mediumGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Get Venue Status Based on Current Time ───────────────────────────────────

  Map<String, dynamic> _getVenueStatus() {
    final now = DateTime.now();

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final todayEvents = _eventsByDate[todayStr] ?? [];

    if (todayEvents.isEmpty) {
      // No events today

      return {
        'isReserved': false,

        'statusText': 'OPEN',

        'subtitleText': 'Ready for Guests',

        'statusColor': AppTheme.successGreen,
      };
    }

    // Sort events by start time

    final sortedEvents = List<Map<String, dynamic>>.from(todayEvents);

    sortedEvents.sort((a, b) {
      final startA = a['event_start'] as DateTime?;

      final startB = b['event_start'] as DateTime?;

      if (startA == null || startB == null) return 0;

      return startA.compareTo(startB);
    });

    // Check current time against events

    for (final event in sortedEvents) {
      final eventStart = event['event_start'] as DateTime?;

      final eventEnd = event['event_end'] as DateTime?;

      final customerName = event['customer_name'] as String? ?? 'Customer';

      final eventType = event['event_type'] as String? ?? 'Event';

      if (eventStart != null && eventEnd != null) {
        if (now.isAfter(eventStart) && now.isBefore(eventEnd)) {
          // Currently in an event

          return {
            'isReserved': true,

            'statusText': 'BOOKED',

            'subtitleText': '$customerName - $eventType in progress',

            'statusColor': AppTheme.primaryColor,
          };
        }
      }
    }

    // Check if there's an upcoming event today (with 30-minute "Booked" buffer)

    final bufferTime = const Duration(minutes: 30);

    for (final event in sortedEvents) {
      final eventStart = event['event_start'] as DateTime?;

      final customerName = event['customer_name'] as String? ?? 'Customer';

      final eventType = event['event_type'] as String? ?? 'Event';

      if (eventStart != null && now.isBefore(eventStart)) {
        final startsIn = eventStart.difference(now);

        final startTime = DateFormat('h:mm a').format(eventStart);

        if (startsIn <= bufferTime) {
          // Within 30 minutes - turn RED/BOOKED

          return {
            'isReserved': true,

            'statusText': 'BOOKED',

            'subtitleText':
                '$customerName - $eventType starting soon ($startTime)',

            'statusColor': AppTheme.primaryColor,
          };
        } else {
          // Not starting yet - stay GREEN/OPEN

          return {
            'isReserved': false,

            'statusText': 'OPEN',

            'subtitleText':
                'Next event: $customerName - $eventType at $startTime',

            'statusColor': AppTheme.successGreen,
          };
        }
      }
    }

    // All events for today are completed

    return {
      'isReserved': false,

      'statusText': 'OPEN',

      'subtitleText': 'All events completed today',

      'statusColor': AppTheme.successGreen,
    };
  }

  // ── Monthly Calendar Widget ────────────────────────────────────────────────

  // ── Monthly Overview Section ────────────────────────────────────────────────

  Widget _buildMonthlyOverview(BuildContext context) {
    _focusedMonth ??= DateTime.now();
    final focusedMonth = _focusedMonth!;
    final now = DateTime.now();
    final targetMonthStr = DateFormat('yyyy-MM').format(focusedMonth);

    // Collect all events for selected month
    List<Map<String, dynamic>> monthEvents = [];
    _eventsByDate.forEach((dateKey, events) {
      if (dateKey.startsWith(targetMonthStr)) {
        for (var e in events) {
          monthEvents.add({...e, 'date_key': dateKey});
        }
      }
    });
    monthEvents.sort((a, b) {
      int d = a['date_key'].compareTo(b['date_key']);
      if (d != 0) return d;
      final sa = a['event_start'] as DateTime?;
      final sb = b['event_start'] as DateTime?;
      if (sa != null && sb != null) return sa.compareTo(sb);
      return (a['start_time'] ?? '').compareTo(b['start_time'] ?? '');
    });

    final confirmedCount = monthEvents.where((e) =>
      (e['status']?.toString().toLowerCase() ?? '') == 'confirmed').length;
    final pendingCount = monthEvents.where((e) =>
      (e['status']?.toString().toLowerCase() ?? '') == 'pending').length;

    // Calendar heat-strip: days with events this month
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final eventDays = <int>{};
    for (final e in monthEvents) {
      try {
        final d = DateTime.parse(e['date_key']);
        eventDays.add(d.day);
      } catch (_) {}
    }

    // Pagination
    final totalItems = monthEvents.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    if (_schedulePage >= totalPages && totalPages > 0) _schedulePage = totalPages - 1;
    final startIndex = _schedulePage * _itemsPerPage;
    final endIndex = min(startIndex + _itemsPerPage, totalItems);
    final displayedEvents = totalItems > 0 ? monthEvents.sublist(startIndex, endIndex) : [];

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
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
                    child: const Icon(Icons.calendar_month_rounded,
                        color: AppTheme.adminPrimaryAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Event Schedule',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppTheme.darkGrey, letterSpacing: -0.3,
                          )),
                      Text(DateFormat('MMMM yyyy').format(focusedMonth),
                          style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
                    ],
                  ),
                ],
              ),
              _buildMonthDropdown(focusedMonth),
            ],
          ),

          const SizedBox(height: 14),

          // ── Summary Stat Chips ─────────────────────────────────────────
          Row(
            children: [
              _scheduleChip(Icons.event_note_rounded, '${monthEvents.length}',
                  'Total', AppTheme.adminPrimaryAccent),
              const SizedBox(width: 8),
              _scheduleChip(Icons.check_circle_rounded, '$confirmedCount',
                  'Confirmed', AppTheme.successGreen),
              const SizedBox(width: 8),
              _scheduleChip(Icons.pending_rounded, '$pendingCount',
                  'Pending', AppTheme.warningOrange),
            ],
          ),

          const SizedBox(height: 14),

          // ── Calendar Heat-Strip ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(focusedMonth).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: AppTheme.adminSecondaryText, letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${eventDays.length} days with events',
                      style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(daysInMonth, (i) {
                      final day = i + 1;
                      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
                      final isToday = now.year == date.year &&
                          now.month == date.month && now.day == date.day;
                      final hasEvent = eventDays.contains(day);
                      final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        width: 28,
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E').format(date)[0],
                              style: TextStyle(
                                fontSize: 8.5, fontWeight: FontWeight.bold,
                                color: isToday ? AppTheme.adminPrimaryAccent : AppTheme.mediumGrey,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 28, height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppTheme.adminPrimaryAccent
                                    : hasEvent
                                        ? AppTheme.successGreen.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                                border: hasEvent && !isToday
                                    ? Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? Colors.white
                                      : hasEvent
                                          ? AppTheme.successGreen
                                          : isPast
                                              ? AppTheme.mediumGrey.withValues(alpha: 0.5)
                                              : AppTheme.darkGrey,
                                ),
                              ),
                            ),
                            if (hasEvent)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 4, height: 4,
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.white : AppTheme.successGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Event List ─────────────────────────────────────────────────
          if (monthEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.adminMainBackground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_rounded,
                        color: AppTheme.mediumGrey.withValues(alpha: 0.4), size: 44),
                    const SizedBox(height: 12),
                    const Text('No events scheduled this month',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 14, color: AppTheme.mediumGrey)),
                    const SizedBox(height: 4),
                    const Text('Check another month or add reservations',
                        style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...displayedEvents.asMap().entries.map((entry) {
                  final event = entry.value;
                  final dateKey = event['date_key'] as String;
                  final status = (event['status']?.toString().toLowerCase() ?? '');
                  final isConfirmed = status == 'confirmed';
                  final isPending = status == 'pending';
                  final isToday = dateKey == DateFormat('yyyy-MM-dd').format(now);
                  final isTodayOrFuture = dateKey.compareTo(DateFormat('yyyy-MM-dd').format(
                      DateTime(now.year, now.month, now.day))) >= 0;

                  // Parse date
                  DateTime? eventDate;
                  try { eventDate = DateTime.parse(dateKey); } catch (_) {}

                  // Parse time
                  String timeStr = '';
                  final eventStart = event['event_start'] as DateTime?;
                  final eventEnd = event['event_end'] as DateTime?;
                  if (eventStart != null && eventEnd != null) {
                    timeStr = '${DateFormat('h:mm a').format(eventStart)} – ${DateFormat('h:mm a').format(eventEnd)}';
                  } else if (event['start_time'] != null) {
                    timeStr = event['start_time'].toString();
                  }

                  final guestCount = event['number_of_guests'] ?? event['pax'] ?? event['guest_count'];
                  final eventType = event['event_type'] ?? 'Event';
                  final customerName = event['customer_name'] ?? 'Guest';
                  final packageName = event['package_name'];

                  Color statusColor = isPending ? AppTheme.warningOrange : AppTheme.successGreen;
                  Color accentColor = isConfirmed ? AppTheme.successGreen : AppTheme.warningOrange;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.adminPrimaryAccent.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.adminPrimaryAccent.withValues(alpha: 0.25)
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Date Block
                        Container(
                          width: 46,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppTheme.adminPrimaryAccent
                                : isTodayOrFuture
                                    ? accentColor.withValues(alpha: 0.1)
                                    : AppTheme.adminMainBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                eventDate != null ? DateFormat('MMM').format(eventDate) : '',
                                style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: isToday ? Colors.white70 : AppTheme.mediumGrey,
                                ),
                              ),
                              Text(
                                eventDate != null ? '${eventDate.day}' : '',
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, height: 1.1,
                                  color: isToday ? Colors.white : accentColor,
                                ),
                              ),
                              Text(
                                eventDate != null ? DateFormat('EEE').format(eventDate) : '',
                                style: TextStyle(
                                  fontSize: 8.5, fontWeight: FontWeight.bold,
                                  color: isToday ? Colors.white60 : AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Event Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(eventType,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5, color: AppTheme.darkGrey,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isToday)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.adminPrimaryAccent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('TODAY',
                                          style: TextStyle(fontSize: 8.5,
                                              fontWeight: FontWeight.w900, color: Colors.white)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 11, color: AppTheme.mediumGrey),
                                  const SizedBox(width: 3),
                                  Text(customerName,
                                      style: const TextStyle(
                                          fontSize: 11, color: AppTheme.mediumGrey)),
                                  if (guestCount != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.people_outline_rounded,
                                        size: 11, color: AppTheme.mediumGrey),
                                    const SizedBox(width: 3),
                                    Text('$guestCount pax',
                                        style: const TextStyle(
                                            fontSize: 11, color: AppTheme.mediumGrey)),
                                  ],
                                ],
                              ),
                              if (timeStr.isNotEmpty || packageName != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (timeStr.isNotEmpty) ...[
                                      const Icon(Icons.schedule_rounded,
                                          size: 10, color: AppTheme.mediumGrey),
                                      const SizedBox(width: 3),
                                      Text(timeStr,
                                          style: const TextStyle(
                                              fontSize: 10.5, color: AppTheme.mediumGrey)),
                                    ],
                                    if (packageName != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('· $packageName',
                                            style: const TextStyle(
                                                fontSize: 10.5, color: AppTheme.mediumGrey),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Status Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isConfirmed ? Icons.check_rounded : Icons.hourglass_top_rounded,
                                    size: 10, color: statusColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isConfirmed ? 'Confirmed' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // Pagination
                if (totalPages > 1) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${startIndex + 1}–$endIndex of $totalItems events',
                          style: const TextStyle(
                            fontSize: 11, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            _paginationBtn(
                              icon: Icons.chevron_left,
                              enabled: _schedulePage > 0,
                              onTap: () => setState(() => _schedulePage--),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.adminPrimaryAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_schedulePage + 1} / $totalPages',
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _paginationBtn(
                              icon: Icons.chevron_right,
                              enabled: _schedulePage < totalPages - 1,
                              onTap: () => setState(() => _schedulePage++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _scheduleChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.mediumGrey)),
        ],
      ),
    );
  }

  Widget _paginationBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.adminPrimaryAccent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? AppTheme.adminPrimaryAccent.withValues(alpha: 0.3) : AppTheme.cardBorder,
          ),
        ),
        child: Icon(icon,
          size: 16,
          color: enabled ? AppTheme.adminPrimaryAccent : AppTheme.mediumGrey.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildMonthDropdown(DateTime focusedMonth) {
    // Generate months from This Year - 1 to This Year + 2

    final now = DateTime.now();

    final List<DateTime> months = [];

    for (int y = now.year - 1; y <= now.year + 2; y++) {
      for (int m = 1; m <= 12; m++) {
        months.add(DateTime(y, m));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: AppTheme.lightGrey),
      ),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: DateTime(focusedMonth.year, focusedMonth.month),

          icon: const Icon(
            Icons.unfold_more,

            size: 16,

            color: AppTheme.mediumGrey,
          ),

          elevation: 2,

          menuMaxHeight: 300,

          borderRadius: BorderRadius.circular(12),

          alignment: Alignment.centerRight,

          style: const TextStyle(
            fontWeight: FontWeight.bold,

            fontSize: 12,

            color: AppTheme.darkGrey,
          ),

          onChanged: (DateTime? newValue) {
            if (newValue != null) {
              setState(() {
                _focusedMonth = newValue;

                _schedulePage = 0; // Reset page on month change
              });
            }
          },

          items: months
              .map(
                (date) => DropdownMenuItem<DateTime>(
                  value: date,

                  child: Text(DateFormat('MMM yyyy').format(date)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOperationsMonitor(BuildContext context) {
    final now = DateTime.now();
    final timeLabel = DateFormat('h:mm a').format(now);
    final totalActive = _pendingOrders + _preparingOrders + _readyOrders;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded,
                        color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Operations Monitor',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppTheme.darkGrey, letterSpacing: -0.3,
                          )),
                      Text('Kitchen & inventory status • $timeLabel',
                          style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(color: const Color(0xFFEF4444), size: 5),
                    const SizedBox(width: 5),
                    const Text('REAL-TIME',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444), letterSpacing: 0.5,
                        )),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Order Pipeline ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.adminPrimaryAccent.withValues(alpha: 0.05),
                  AppTheme.adminPrimaryAccent.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ORDER PIPELINE',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          color: AppTheme.adminPrimaryAccent, letterSpacing: 0.8,
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimaryAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$totalActive Active',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildPipelineStage(
                      icon: Icons.receipt_long_rounded,
                      label: 'Pending',
                      count: _pendingOrders,
                      color: AppTheme.warningOrange,
                      isFirst: true,
                    )),
                    _pipelineArrow(),
                    Expanded(child: _buildPipelineStage(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Preparing',
                      count: _preparingOrders,
                      color: const Color(0xFFF59E0B),
                      isFirst: false,
                    )),
                    _pipelineArrow(),
                    Expanded(child: _buildPipelineStage(
                      icon: Icons.check_circle_rounded,
                      label: 'Ready',
                      count: _readyOrders,
                      color: AppTheme.successGreen,
                      isFirst: false,
                    )),
                  ],
                ),
                if (totalActive > 0) ...[
                  const SizedBox(height: 10),
                  // Progress bar showing pipeline distribution
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        if (_pendingOrders > 0)
                          Expanded(
                            flex: _pendingOrders,
                            child: Container(height: 5,
                                color: AppTheme.warningOrange.withValues(alpha: 0.7)),
                          ),
                        if (_preparingOrders > 0)
                          Expanded(
                            flex: _preparingOrders,
                            child: Container(height: 5,
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.8)),
                          ),
                        if (_readyOrders > 0)
                          Expanded(
                            flex: _readyOrders,
                            child: Container(height: 5,
                                color: AppTheme.successGreen.withValues(alpha: 0.8)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Inventory Status ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.adminMainBackground.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INVENTORY HEALTH',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: AppTheme.adminSecondaryText, letterSpacing: 0.8,
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInventoryStatusTile(
                        icon: Icons.remove_shopping_cart_rounded,
                        label: 'Out of Stock',
                        count: _outOfStock,
                        color: const Color(0xFFEF4444),
                        isAlert: _outOfStock > 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInventoryStatusTile(
                        icon: Icons.warning_amber_rounded,
                        label: 'Low Stock',
                        count: _lowStock,
                        color: AppTheme.warningOrange,
                        isAlert: _lowStock > 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInventoryStatusTile(
                        icon: Icons.inventory_2_rounded,
                        label: 'Sufficient',
                        count: 0,
                        color: AppTheme.successGreen,
                        isAlert: false,
                        showAsOk: true,
                      ),
                    ),
                  ],
                ),
                if (_outOfStock > 0 || _lowStock > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _outOfStock > 0
                                ? '$_outOfStock item${_outOfStock > 1 ? 's' : ''} out of stock — restock needed immediately'
                                : '$_lowStock item${_lowStock > 1 ? 's' : ''} running low — consider restocking soon',
                            style: const TextStyle(
                              fontSize: 10.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Quick Stats Row ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _buildOpsQuickStat(
                icon: Icons.event_available_rounded,
                label: 'Confirmed Events',
                value: '$_reservations',
                color: AppTheme.successGreen,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildOpsQuickStat(
                icon: Icons.pending_actions_rounded,
                label: 'Pending Approval',
                value: '$_pendingReservations',
                color: AppTheme.warningOrange,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildOpsQuickStat(
                icon: Icons.people_alt_rounded,
                label: 'Guests Today',
                value: '$_totalCustomers',
                color: AppTheme.infoBlue,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStage({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isFirst,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: count > 0 ? 0.3 : 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: count > 0 ? color : AppTheme.mediumGrey),
          const SizedBox(height: 4),
          Text(
            count.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: count > 0 ? color : AppTheme.mediumGrey,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _pipelineArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right_rounded,
          color: AppTheme.mediumGrey.withValues(alpha: 0.5), size: 20),
    );
  }

  Widget _buildInventoryStatusTile({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isAlert,
    bool showAsOk = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAlert ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isAlert ? 0.25 : 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            showAsOk ? '—' : count.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: isAlert ? color : AppTheme.mediumGrey, height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildOpsQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: color, height: 1.1,
                    )),
                Text(label,
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity(BuildContext context) {
    final totalItems = _recentActivity.length;
    final totalPages = totalItems > 0 ? (totalItems / _activityItemsPerPage).ceil() : 1;
    if (_activityCurrentPage > totalPages) {
      _activityCurrentPage = totalPages;
    }
    if (_activityCurrentPage < 1) {
      _activityCurrentPage = 1;
    }

    final startIndex = (_activityCurrentPage - 1) * _activityItemsPerPage;
    final endIndex = (startIndex + _activityItemsPerPage < totalItems)
        ? startIndex + _activityItemsPerPage
        : totalItems;

    final paginatedActivity = totalItems > 0
        ? _recentActivity.sublist(startIndex, endIndex)
        : <_ActivityItem>[];

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timeline_rounded,
                        color: AppTheme.infoBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Activity',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppTheme.darkGrey, letterSpacing: -0.3,
                          )),
                      Text('${_recentActivity.length} events logged today',
                          style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showAllActivityDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.adminPrimaryAccent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new_rounded,
                          size: 12, color: AppTheme.adminPrimaryAccent),
                      const SizedBox(width: 4),
                      const Text('View All',
                          style: TextStyle(
                            color: AppTheme.adminPrimaryAccent,
                            fontSize: 11.5, fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.adminMainBackground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded,
                        color: AppTheme.mediumGrey.withValues(alpha: 0.4), size: 40),
                    const SizedBox(height: 10),
                    const Text('No recent activity',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 13, color: AppTheme.mediumGrey)),
                    const SizedBox(height: 3),
                    const Text('Activity will appear here as orders, bookings, and alerts come in',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.mediumGrey),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else ...[
            Column(
              children: List.generate(
                paginatedActivity.length,
                (index) {
                  final item = paginatedActivity[index];
                  final isLast = index == paginatedActivity.length - 1;
                  return _buildActivityTimelineItem(item, isLast);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentActivityPagination(
              totalItems: totalItems,
              currentPage: _activityCurrentPage,
              totalPages: totalPages,
              onPageChanged: (newPage) {
                setState(() {
                  _activityCurrentPage = newPage;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivityPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _activityItemsPerPage) + 1;
    final endItem = (currentPage * _activityItemsPerPage < totalItems)
        ? currentPage * _activityItemsPerPage
        : totalItems;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of $totalItems',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumGrey,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev Button
              InkWell(
                onTap: currentPage > 1
                    ? () {
                        onPageChanged(currentPage - 1);
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentPage > 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: currentPage > 1 ? AppTheme.cardBorder : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 15,
                        color: currentPage > 1 ? AppTheme.darkGrey : AppTheme.mediumGrey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Prev',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: currentPage > 1 ? AppTheme.darkGrey : AppTheme.mediumGrey.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Page indicators (1, 2, 3...)
              ...List.generate(totalPages, (index) {
                final pageNum = index + 1;
                if (totalPages > 5) {
                  if (pageNum != 1 &&
                      pageNum != totalPages &&
                      (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                    if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Text('…', style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey)),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                }

                final isSelected = pageNum == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        onPageChanged(pageNum);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.adminPrimaryAccent : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppTheme.adminPrimaryAccent : AppTheme.cardBorder,
                        ),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 6),

              // Next Button
              InkWell(
                onTap: currentPage < totalPages
                    ? () {
                        onPageChanged(currentPage + 1);
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentPage < totalPages ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: currentPage < totalPages ? AppTheme.cardBorder : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: currentPage < totalPages ? AppTheme.darkGrey : AppTheme.mediumGrey.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: currentPage < totalPages ? AppTheme.darkGrey : AppTheme.mediumGrey.withValues(alpha: 0.4),
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

  Widget _buildActivityTimelineItem(_ActivityItem item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line + Dot
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: item.color.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Icon(item.icon, size: 15, color: item.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: AppTheme.cardBorder,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: item.color.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5, color: AppTheme.darkGrey,
                            )),
                        const SizedBox(height: 2),
                        Text(item.subtitle,
                            style: const TextStyle(
                              fontSize: 11, color: AppTheme.mediumGrey, height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.adminMainBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(item.time,
                        style: const TextStyle(
                          fontSize: 9.5, color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllActivityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 640, maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.adminPrimaryAccent.withValues(alpha: 0.08),
                      AppTheme.adminPrimaryAccent.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimaryAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timeline_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Full Activity Feed',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                  color: AppTheme.darkGrey)),
                          Text('All logged system events and transactions',
                              style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppTheme.mediumGrey),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Activity List
              Flexible(
                child: _recentActivity.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No recent activity recorded',
                              style: TextStyle(color: AppTheme.mediumGrey)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentActivity.length,
                        itemBuilder: (context, index) {
                          final item = _recentActivity[index];
                          final isLast = index == _recentActivity.length - 1;
                          return _buildActivityTimelineItem(item, isLast);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Confirmed Events Analytics Widget ─────────────────────────────────────

  Widget _buildConfirmedEventsAnalytics(BuildContext context, bool isWide) {
    if (_eventTypeDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.xl),

        decoration: _confirmedEventsCardDecoration(),

        child: Column(
          children: [
            Icon(
              Icons.event_busy,

              color: AppTheme.mediumGrey.withValues(alpha: 0.5),

              size: 48,
            ),

            const SizedBox(height: AppTheme.md),

            Text(
              'No confirmed events yet',

              style: TextStyle(color: AppTheme.mediumGrey, fontSize: 16),
            ),

            const SizedBox(height: AppTheme.sm),

            Text(
              'Analytics will appear once events are confirmed',

              style: TextStyle(color: AppTheme.mediumGrey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final monthLabels = [
      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',
    ];

    final maxEvents = _monthlyEventTrends.isEmpty
        ? 0.0
        : _monthlyEventTrends.reduce(max);

    final maxY = (maxEvents == 0 ? 5.0 : maxEvents * 1.2)
        .clamp(5.0, 50.0)
        .toDouble();

    return Column(
      children: [
        // Charts Section (Visual Analytics)
        if (isWide)
          Row(
            children: [
              // Monthly Trends Chart
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.adminConfirmedEventsBorder, AppTheme.adminConfirmedEventsBorder],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Monthly Event Trends - ${DateTime.now().year}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGrey,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.lg),
                      SizedBox(
                        height: 200,
                        child: SfCartesianChart(
                          plotAreaBorderWidth: 0,
                          margin: EdgeInsets.zero,
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            activationMode: ActivationMode.singleTap,
                            shouldAlwaysShow: false,
                            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                              final _EventTrendData item = data;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.adminPrimaryText,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.value.toInt()} events\n${item.month}',
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
                            labelStyle: const TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            axisLine: const AxisLine(width: 1, color: AppTheme.cardBorder),
                          ),
                          primaryYAxis: NumericAxis(
                            axisLine: const AxisLine(width: 0),
                            labelStyle: const TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            majorGridLines: MajorGridLines(
                              color: AppTheme.adminCardBackground.withValues(alpha: 0.8),
                              width: 1,
                            ),
                            maximum: maxY,
                          ),
                          series: <CartesianSeries<_EventTrendData, String>>[
                            SplineAreaSeries<_EventTrendData, String>(
                              dataSource: List.generate(12, (i) {
                                return _EventTrendData(monthLabels[i], _monthlyEventTrends[i]);
                              }),
                              xValueMapper: (_EventTrendData data, _) => data.month,
                              yValueMapper: (_EventTrendData data, _) => data.value,
                              name: 'Events',
                              enableTooltip: true,
                              animationDuration: 0,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                                  AppTheme.primaryLight.withValues(alpha: 0.1),
                                  AppTheme.primaryColor.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderColor: AppTheme.primaryColor,
                              borderWidth: 3,
                              markerSettings: const MarkerSettings(
                                isVisible: true,
                                shape: DataMarkerType.circle,
                                width: 6,
                                height: 6,
                                color: Colors.white,
                                borderColor: AppTheme.primaryColor,
                                borderWidth: 2,
                              ),
                              dataLabelSettings: DataLabelSettings(
                                isVisible: true,
                                labelAlignment: ChartDataLabelAlignment.top,
                                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                  final _EventTrendData item = data;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      item.value.toInt().toString(),
                                      style: const TextStyle(
                                        color: AppTheme.darkGrey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.lg),

              // Event Type Distribution
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.lg),

                  decoration: _cardDecoration(),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,

                            height: 20,

                            decoration: BoxDecoration(
                              color: AppTheme.adminPrimaryAccent,

                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Text(
                            'Top Event Types',

                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,

                                  color: AppTheme.darkGrey,
                                ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.lg),

                      ..._topEventTypes
                          .take(5)
                          .map(
                            (eventType) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.sm,
                              ),

                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          eventType['event_type'] ?? 'Unknown',

                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,

                                            fontSize: 12,

                                            color: AppTheme.darkGrey,
                                          ),
                                        ),

                                        Text(
                                          '${eventType['count']} events',

                                          style: TextStyle(
                                            fontSize: 10,

                                            color: AppTheme.mediumGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,

                                      vertical: 4,
                                    ),

                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),

                                      borderRadius: BorderRadius.circular(12),
                                    ),

                                    child: Text(
                                      '${eventType['percentage']}%',

                                      style: const TextStyle(
                                        fontSize: 10,

                                        fontWeight: FontWeight.bold,

                                        color: AppTheme.adminPrimaryAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              // Monthly Trends Chart
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.adminPrimaryAccent, AppTheme.adminChatButton],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Monthly Event Trends - ${DateTime.now().year}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.lg),
                    SizedBox(
                      height: 180,
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          activationMode: ActivationMode.singleTap,
                          shouldAlwaysShow: false,
                          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                            final _EventTrendData item = data;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.adminPrimaryText,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.value.toInt()} events\n${item.month}',
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
                          labelStyle: const TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          axisLine: const AxisLine(width: 1, color: AppTheme.cardBorder),
                        ),
                        primaryYAxis: NumericAxis(
                          axisLine: const AxisLine(width: 0),
                          labelStyle: const TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          majorGridLines: MajorGridLines(
                            color: AppTheme.adminCardBackground.withValues(alpha: 0.8),
                            width: 1,
                          ),
                          maximum: maxY,
                        ),
                        series: <CartesianSeries<_EventTrendData, String>>[
                          SplineAreaSeries<_EventTrendData, String>(
                            dataSource: List.generate(12, (i) {
                              return _EventTrendData(monthLabels[i], _monthlyEventTrends[i]);
                            }),
                            xValueMapper: (_EventTrendData data, _) => data.month,
                            yValueMapper: (_EventTrendData data, _) => data.value,
                            name: 'Events',
                            enableTooltip: true,
                            animationDuration: 0,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.3),
                                AppTheme.primaryLight.withValues(alpha: 0.1),
                                AppTheme.primaryColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderColor: AppTheme.primaryColor,
                            borderWidth: 3,
                            markerSettings: const MarkerSettings(
                              isVisible: true,
                              shape: DataMarkerType.circle,
                              width: 6,
                              height: 6,
                              color: Colors.white,
                              borderColor: AppTheme.primaryColor,
                              borderWidth: 2,
                            ),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              labelAlignment: ChartDataLabelAlignment.top,
                              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                final _EventTrendData item = data;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    item.value.toInt().toString(),
                                    style: const TextStyle(
                                      color: AppTheme.darkGrey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.lg),

              // Event Type Distribution
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),

                decoration: _cardDecoration(),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,

                          height: 20,

                          decoration: BoxDecoration(
                            color: AppTheme.adminPrimaryAccent,

                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Text(
                          'Top Event Types',

                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,

                                color: AppTheme.darkGrey,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.lg),

                    ..._topEventTypes
                        .take(5)
                        .map(
                          (eventType) => Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.sm),

                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        eventType['event_type'] ?? 'Unknown',

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,

                                          color: AppTheme.darkGrey,
                                        ),
                                      ),

                                      Text(
                                        '${eventType['count']} events',

                                        style: TextStyle(
                                          fontSize: 10,

                                          color: AppTheme.mediumGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,

                                    vertical: 4,
                                  ),

                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),

                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: Text(
                                    '${eventType['percentage']}%',

                                    style: const TextStyle(
                                      fontSize: 10,

                                      fontWeight: FontWeight.bold,

                                      color: AppTheme.adminPrimaryAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLiveEventsMonitor(BuildContext context) {
    final hasEvents = _ongoingEvents.isNotEmpty || _upcomingEvents.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.adminPrimaryAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Live Event Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const Spacer(),
              if (hasEvents)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(color: Colors.green, size: 6),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          if (!hasEvents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: AppTheme.mediumGrey.withValues(alpha: 0.4),
                      size: 44,
                    ),
                    const SizedBox(height: AppTheme.md),
                    const Text(
                      'No active or upcoming events right now',
                      style: TextStyle(
                        color: AppTheme.darkGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Check the Monthly Event Schedule below for other dates.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mediumGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Ongoing Events
            if (_ongoingEvents.isNotEmpty) ...[
              Row(
                children: [
                  const _PulsingDot(color: AppTheme.successGreen, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    '${_ongoingEvents.length} Ongoing Event${_ongoingEvents.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Live Now',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._ongoingEvents
                  .take(2)
                  .map((event) => _buildLiveEventTile(event, true)),
              if (_ongoingEvents.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${_ongoingEvents.length - 2} more ongoing...',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ),
            ],

            if (_ongoingEvents.isNotEmpty && _upcomingEvents.isNotEmpty)
              const SizedBox(height: AppTheme.lg),

            // Upcoming Events
            if (_upcomingEvents.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.warningOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_upcomingEvents.length} Upcoming Event${_upcomingEvents.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Next 24 Hours',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._upcomingEvents
                  .take(2)
                  .map((event) => _buildLiveEventTile(event, false)),
              if (_upcomingEvents.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${_upcomingEvents.length - 2} more scheduled...',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLiveEventTile(Map<String, dynamic> event, bool isOngoing) {
    final eventStart = event['event_start'] as DateTime?;

    final eventEnd = event['event_end'] as DateTime?;

    final now = DateTime.now();

    String timeText = '';

    Color statusColor = isOngoing
        ? AppTheme.successGreen
        : AppTheme.warningOrange;

    if (isOngoing && eventEnd != null) {
      final remaining = eventEnd.difference(now);

      if (remaining.inHours > 0) {
        timeText =
            '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
      } else {
        timeText = '${remaining.inMinutes}m remaining';
      }
    } else if (!isOngoing && eventStart != null) {
      final waitTime = eventStart.difference(now);

      if (waitTime.inHours > 0) {
        timeText = 'Starts in ${waitTime.inHours}h ${waitTime.inMinutes % 60}m';
      } else {
        timeText = 'Starts in ${waitTime.inMinutes}m';
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),

      margin: const EdgeInsets.only(bottom: 4),

      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),

      child: Row(
        children: [
          Container(
            width: 6,

            height: 6,

            decoration: BoxDecoration(
              color: statusColor,

              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  event['event_type'] ?? 'Event',

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,

                    fontSize: 11,

                    color: AppTheme.darkGrey,
                  ),
                ),

                Text(
                  '${event['customer_name']} · ${event['number_of_guests']} guests',

                  style: TextStyle(fontSize: 9, color: AppTheme.mediumGrey),
                ),
              ],
            ),
          ),

          Text(
            timeText,

            style: TextStyle(
              fontSize: 9,

              fontWeight: FontWeight.bold,

              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventStatusColor(Map<String, dynamic> event) {
    final now = DateTime.now();

    final eventStart = event['event_start'] as DateTime?;

    final eventEnd = event['event_end'] as DateTime?;

    if (eventStart != null && eventEnd != null) {
      if (now.isAfter(eventStart) && now.isBefore(eventEnd)) {
        return AppTheme.successGreen; // Ongoing
      } else if (now.isBefore(eventStart)) {
        final waitTime = eventStart.difference(now);

        if (waitTime.inMinutes <= 30) {
          return AppTheme.errorRed; // Starting soon
        } else {
          return AppTheme.warningOrange; // Upcoming
        }
      }
    }

    return AppTheme.mediumGrey; // Ended/Unknown
  }

  String _getEventStatusText(Map<String, dynamic> event) {
    final now = DateTime.now();

    final eventStart = event['event_start'] as DateTime?;

    final eventEnd = event['event_end'] as DateTime?;

    if (eventStart != null && eventEnd != null) {
      if (now.isAfter(eventStart) && now.isBefore(eventEnd)) {
        return 'LIVE NOW';
      } else if (now.isBefore(eventStart)) {
        final waitTime = eventStart.difference(now);

        if (waitTime.inMinutes <= 30) {
          return 'STARTING SOON';
        } else {
          return 'UPCOMING';
        }
      }
    }

    return 'ENDED';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      border: Border.all(color: AppTheme.cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  BoxDecoration _confirmedEventsCardDecoration() {
    return BoxDecoration(
      color: AppTheme.adminConfirmedEventsBg,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: AppTheme.adminConfirmedEventsBorder, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _formatNumber(dynamic n) {
    final numValue = n is double ? n : (n as int).toDouble();

    if (numValue >= 1000000) {
      return '₱${(numValue / 1000000).toStringAsFixed(2)}m';
    }

    // Always show exact amount with centavos using comma separators

    final formatter = NumberFormat('#,##0.00', 'en_US');

    return '₱${formatter.format(numValue)}';
  }

  String _formatDate() {
    final now = DateTime.now();

    const months = [
      'January',

      'February',

      'March',

      'April',

      'May',

      'June',

      'July',

      'August',

      'September',

      'October',

      'November',

      'December',
    ];

    const days = [
      'Monday',

      'Tuesday',

      'Wednesday',

      'Thursday',

      'Friday',

      'Saturday',

      'Sunday',
    ];

    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // ── Real-time Notification Widget ───────────────────────────────────────

  Widget _buildNewOrderNotification() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.successGreen,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withValues(alpha: 0.3),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),

              borderRadius: BorderRadius.circular(8),
            ),

            child: const Icon(
              Icons.receipt_long,

              color: Colors.white,

              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [
              const Text(
                'NEW ORDER!',

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 12,

                  fontWeight: FontWeight.bold,

                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                _newOrderAmount,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 16,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── New Reservation Notification Widget ─────────────────────────────

  Widget _buildNewReservationNotification() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.adminProgressBar2,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: AppTheme.infoBlue.withValues(alpha: 0.3),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),

              borderRadius: BorderRadius.circular(8),
            ),

            child: const Icon(
              Icons.event_available,

              color: Colors.white,

              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [
              const Text(
                'NEW RESERVATION!',

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 12,

                  fontWeight: FontWeight.bold,

                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                _newReservationInfo,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 14,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── New Advance Order Notification Widget ─────────────────────────────

  Widget _buildNewAdvanceOrderNotification() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.warningOrange,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: AppTheme.warningOrange.withValues(alpha: 0.3),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),

              borderRadius: BorderRadius.circular(8),
            ),

            child: const Icon(
              Icons.calendar_today,

              color: Colors.white,

              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [
              const Text(
                'NEW ADVANCE ORDER!',

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 12,

                  fontWeight: FontWeight.bold,

                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                _newAdvanceOrderInfo,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 14,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Period Selector Widget ───────────────────────────────────────────────

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: AppTheme.cardBorder),
      ),

      child: DropdownButton<String>(
        focusNode: _dashboardPeriodFocusNode,
        value: _selectedPeriod,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: ['Daily', 'Weekly', 'Monthly', 'Annually']
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (v) {
          _dashboardPeriodFocusNode.unfocus();
          if (mounted && v != null) {
            setState(() {
              _selectedPeriod = v;
              _weeklyRevenue = _processChartData(_lastOrders);
            });
          }
        },
      ),
    );
  }
}

class _RevenueData {
  _RevenueData(this.label, this.value);
  final String label;
  final double value;
}

class _EventTrendData {
  _EventTrendData(this.month, this.value);
  final String month;
  final double value;
}

class _PieData {
  _PieData(this.x, this.y, this.color);
  final String x;
  final double y;
  final Color color;
}

// ── Data models ───────────────────────────────────────────────────────────────

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, this.size = 8.0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 2.2,
          height: size * 2.2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
