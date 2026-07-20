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

  // ── UI State Variables ───────────────────────────────────────────────

  bool? _isVenueStatusExpanded; // Start expanded by default

  DateTime? _focusedMonth;

  String _selectedPeriod = 'Weekly'; // New period selector state

  final String _selectedYear = '2026'; // New year selector state

  int _schedulePage = 0;

  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();

    // Initialize state variables

    _isVenueStatusExpanded = true;

    _showNewOrderNotification = false;

    _showNewReservationNotification = false;

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
                  DateTime.now().toIso8601String(),

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

    super.dispose();
  }

  void _processData(
    List<Map<String, dynamic>> allOrders,

    List<Map<String, dynamic>> allAdvanceOrders,

    List<Map<String, dynamic>> allInventory,

    List<Map<String, dynamic>> allReservations,
  ) {
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

    // Admin Dashboard daily revenue: Regular orders only
    // (Advance orders and event reservations are tracked separately in Sales Report)
    _dailyRevenue = regularRevenue;

    _totalOrders = todayOrders.length;

    _totalAdvanceOrders = paidAdvanceOrders.length;

    // Count total guest count (pax) from today's orders (default to 1 if null)

    final regularCustomers = todayOrders.fold<int>(
      0,
      (sum, o) => sum + ((o['number_of_guests'] as num?)?.toInt() ?? 1),
    );

    final advanceCustomers = todayPaidAdvanceOrders.fold<int>(
      0,
      (sum, o) => sum + ((o['number_of_guests'] as num?)?.toInt() ?? 1),
    );

    // Count guests from confirmed event reservations happening today
    final reservationCustomers = allReservations.where((r) {
      final eventDate = r['event_date']?.toString() ?? '';
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return eventDate == todayStr && status == 'confirmed';
    }).fold<int>(
      0,
      (sum, r) => sum + ((r['number_of_guests'] as num?)?.toInt() ?? 0),
    );

    _totalCustomers = regularCustomers + advanceCustomers + reservationCustomers;

    // Reservations (Events) - Count all active confirmed and pending reservations

    final confirmedReservations = allReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();

      return status == 'confirmed';
    }).toList();

    _reservations = confirmedReservations.length;

    final pendingReservations = allReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();

      return status == 'pending' || status == 'pending_admin_approval';
    }).toList();

    final pendingAdvanceVerification = allAdvanceOrders.where((o) {
      final status = (o['status']?.toString() ?? '').toLowerCase();

      return status == 'awaiting_verification';
    }).toList();

    _pendingReservations =
        pendingReservations.length + pendingAdvanceVerification.length;

    // Weekly Revenue Calculation (Regular orders only)

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

    _updateActivity(todayOrders, allInventory, allReservations);

    // Process Confirmed Events Analytics

    _processConfirmedEventsAnalytics(allReservations);

    // Process Real-time Event Status

    _processRealtimeEventStatus(allReservations);
  }

  void _processConfirmedEventsAnalytics(
    List<Map<String, dynamic>> allReservations,
  ) {
    // Filter only confirmed reservations

    final confirmedReservations = allReservations.where((r) {
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

    _updateNextEventCountdown();

    // Recalculate current guests on site (in case events ended)

    final now = DateTime.now();

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
      // Business hours only: 10:00 AM to 8:00 PM (10:00 to 20:00)

      return [
        '10:00',

        '11:00',

        '12:00',

        '13:00',

        '14:00',

        '15:00',

        '16:00',

        '17:00',

        '18:00',

        '19:00',

        '20:00',
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
      // Annual - 2016 to current year (2026)

      return [
        '2016',

        '2017',

        '2018',

        '2019',

        '2020',

        '2021',

        '2022',

        '2023',

        '2024',

        '2025',

        '2026',
      ];
    }
  }

  List<double> _processChartData(
    List<Map<String, dynamic>> orders,
  ) {
    final now = DateTime.now();

    Map<int, double> periodData = {};

    // Helper to process a list of orders/reservations

    void processList(
      List<Map<String, dynamic>> list, {
      required bool isAdvance,
      required bool isReservation,
    }) {
      for (var item in list) {
        // Use payment approval timestamps instead of scheduled dates
        final dateStr = isReservation
            ? (item['payment_date'] ?? item['updated_at'])
            : (isAdvance ? item['updated_at'] : item['created_at']);

        final date = DateTime.tryParse(dateStr ?? '');

        if (date == null) continue;

        if (isAdvance) {
          final isPaid =
              item['payment_status'] == 'paid' ||
              item['payment_status'] == 'fully_paid';

          if (!isPaid) continue;
        } else if (isReservation) {
          final paymentStatus = item['payment_status']?.toString() ?? '';

          final isPaid =
              paymentStatus == 'paid' ||
              paymentStatus == 'fully_paid' ||
              paymentStatus == 'deposit_paid';

          if (!isPaid) continue;
        }

        double amount = 0.0;

        if (isReservation) {
          final paymentStatus = item['payment_status']?.toString() ?? '';

          if (paymentStatus == 'deposit_paid') {
            // When deposit is paid, count only the deposit amount
            amount = (item['deposit_amount'] as num?)?.toDouble() ??
                ((item['total_price'] as num?)?.toDouble() ?? 0.0) / 2;
          } else if (paymentStatus == 'fully_paid' || paymentStatus == 'paid') {
            // When fully paid, count only the remaining balance (total - deposit)
            // to avoid double-counting the deposit
            final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
            final depositAmount = (item['deposit_amount'] as num?)?.toDouble() ?? 0.0;
            amount = totalPrice - depositAmount;
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
                date.hour >= 10 &&
                date.hour <= 20) {
              // Map hour to 0-based index within business hours (10:00–20:00)
              final key = date.hour - 10;
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

    // Admin Dashboard chart: Regular orders only
    // (Advance orders and event reservations are tracked separately in Sales Report)
    processList(orders, isAdvance: false, isReservation: false);

    // Convert to list based on selected period

    if (_selectedPeriod == 'Daily') {
      return List.generate(
        11,

        (i) => periodData[i] ?? 0.0,
      ); // 11 business hours: 10:00-20:00
    } else if (_selectedPeriod == 'Weekly') {
      return List.generate(7, (i) => periodData[i] ?? 0.0);
    } else if (_selectedPeriod == 'Monthly') {
      return List.generate(12, (i) => periodData[i] ?? 0.0);
    } else {
      // For yearly, generate from 2016 to current year

      final currentYear = now.year;

      final yearRange = currentYear - 2016 + 1;

      return List.generate(yearRange, (i) => periodData[i] ?? 0.0);
    }
  }

  void _updateActivity(
    List<Map<String, dynamic>> recentOrders,

    List<Map<String, dynamic>> inventory,

    List<Map<String, dynamic>> reservations,
  ) {
    List<_ActivityItem> activities = [];

    // Latest 2 Orders

    for (var i = 0; i < min(2, recentOrders.length); i++) {
      final o = recentOrders[i];

      final time = DateTime.tryParse(o['created_at'] ?? '');

      final timeStr = time != null
          ? DateFormat('HH:mm').format(time)
          : 'Just now';

      activities.add(
        _ActivityItem(
          icon: Icons.receipt_long,

          color: AppTheme.successGreen,

          title: 'Order #${o['transaction_id'] ?? o['id']} Completed',

          subtitle: '${o['customer_name'] ?? 'Guest'} · ₱${o['total_amount']}',

          time: timeStr,
        ),
      );
    }

    // Latest Reservation (show confirmed or recent)

    if (reservations.isNotEmpty) {
      final r = reservations.first;

      final status = r['status']?.toString() ?? 'pending';

      final isConfirmed = status == 'confirmed';

      activities.add(
        _ActivityItem(
          icon: isConfirmed ? Icons.check_circle : Icons.event_available,

          color: isConfirmed ? AppTheme.successGreen : AppTheme.infoBlue,

          title: isConfirmed ? 'Reservation Confirmed' : 'New Reservation',

          subtitle: '${r['customer_name']} · ${r['event_type']}',

          time: 'Just now',
        ),
      );
    }

    // Low Stock Alerts

    final lowStockItems = inventory
        .where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) < 10)
        .take(2)
        .toList();

    for (var item in lowStockItems) {
      activities.add(
        _ActivityItem(
          icon: Icons.inventory_2,

          color: AppTheme.warningOrange,

          title: 'Low Stock Alert',

          subtitle: '${item['item_name']} · ${item['quantity']} left',

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

    return StreamBuilder<List<Map<String, dynamic>>>(
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
                                ? const EdgeInsets.all(AppTheme.md)
                                : const EdgeInsets.all(AppTheme.lg),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                _buildGreeting(context),

                                const SizedBox(height: AppTheme.xl),

                                // ── KPI Cards ──────────────────────────────
                                _buildSectionTitle(
                                  context,
                                  'Today\'s Overview',
                                ),

                                const SizedBox(height: AppTheme.md),

                                _buildKpiGrid(isDesktop || isTablet),

                                const SizedBox(height: AppTheme.xl),

                                // ── Charts Layout with Centered Venue Status ──────────────────
                                ResponsiveUtils.isMobile(context)
                                    ? Column(
                                        children: [
                                          _buildRevenueChart(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildLiveEventsMonitor(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildVenueStatus(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildConfirmedEventsAnalytics(context, false),
                                        ],
                                      )
                                    : (isDesktop || isTablet)
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Expanded(
                                            flex: 3,

                                            child: Column(
                                              children: [
                                                _buildRevenueChart(context),

                                                const SizedBox(
                                                  height: AppTheme.lg,
                                                ),

                                                _buildLiveEventsMonitor(context),

                                                const SizedBox(
                                                  height: AppTheme.lg,
                                                ),

                                                _buildVenueStatus(context),

                                                const SizedBox(
                                                  height: AppTheme.lg,
                                                ),

                                                _buildConfirmedEventsAnalytics(context, true),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _buildRevenueChart(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildLiveEventsMonitor(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildVenueStatus(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildConfirmedEventsAnalytics(context, false),
                                        ],
                                      ),

                                const SizedBox(height: AppTheme.xl),

                                const SizedBox(height: AppTheme.xl),

                                // ── Monthly Event Schedule ──────────────────────────────────
                                _buildSectionTitle(
                                  context,
                                  'Monthly Event Schedule',
                                ),

                                const SizedBox(height: AppTheme.md),

                                _buildMonthlyOverview(context),

                                const SizedBox(height: AppTheme.xl),

                                ResponsiveUtils.isMobile(context)
                                    ? Column(
                                        children: [
                                          _buildOperationsMonitor(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildRecentActivity(context),
                                        ],
                                      )
                                    : (isDesktop || isTablet)
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Expanded(
                                            flex: 3,

                                            child: Column(
                                              children: [
                                                _buildOperationsMonitor(
                                                  context,
                                                ),

                                                const SizedBox(
                                                  height: AppTheme.lg,
                                                ),

                                                _buildRecentActivity(context),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _buildOperationsMonitor(context),

                                          const SizedBox(height: AppTheme.lg),

                                          _buildRecentActivity(context),
                                        ],
                                      ),

                                const SizedBox(height: AppTheme.xxl),
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
    );
  }

  // ── Greeting & Header ──────────────────────────────────────────────────

  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  '$greeting, Administrator!',

                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.darkGrey,

                    fontWeight: FontWeight.bold,

                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    Text(
                      _formatDate(),

                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mediumGrey,

                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      width: 4,

                      height: 4,

                      decoration: const BoxDecoration(
                        color: AppTheme.mediumGrey,

                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────

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

  // ── Clickable Section Title ─────────────────────────────────────────────────────────

  // ── KPI Grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(bool isWide) {
    final cards = [
      _KpiData(
        label: 'DAILY REVENUE',

        value: _formatNumber(_dailyRevenue),

        icon: Icons.payments_rounded,

        color: AppTheme.primaryColor,

        sub: '',

        subPositive: null,

        isHighlight: true,
      ),

      _KpiData(
        label: 'REGULAR ORDERS',

        value: '$_totalOrders',

        icon: Icons.shopping_cart_outlined,

        color: AppTheme.infoBlue,

        sub: '',

        subPositive: null,

        showProgress: true,
      ),

      _KpiData(
        label: 'ADVANCE ORDERS',

        value: '$_totalAdvanceOrders',

        icon: Icons.event_note_outlined,

        color: const Color(0xFF8B5CF6),

        sub: '',

        subPositive: _totalAdvanceOrders > 0,
      ),

      _KpiData(
        label: 'GUESTS TODAY',

        value: '$_totalCustomers',

        icon: Icons.people_outline,

        color: AppTheme.successGreen,

        sub: '',

        subPositive: null,
      ),

      _KpiData(
        label: 'CONFIRMED EVENTS',

        value: '$_reservations',

        icon: Icons.confirmation_number_outlined,

        color: AppTheme.successGreen,

        sub: '',

        subPositive: _pendingReservations > 0,

        extra: 'Total Confirmed',
      ),
    ];

    // Mobile: single column, Tablet: 2x2 grid, Desktop: 4 columns

    if (ResponsiveUtils.isMobile(context)) {
      return Column(
        children: cards
            .map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.md),

                child: _KpiCard(data: d),
              ),
            )
            .toList(),
      );
    }

    if (isWide) {
      return Row(
        children: cards
            .map(
              (d) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppTheme.md),

                  child: _KpiCard(data: d),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(data: cards[0])),

            const SizedBox(width: AppTheme.md),

            Expanded(child: _KpiCard(data: cards[1])),
          ],
        ),

        const SizedBox(height: AppTheme.md),

        Row(
          children: [
            Expanded(child: _KpiCard(data: cards[2])),

            const SizedBox(width: AppTheme.md),

            Expanded(child: _KpiCard(data: cards[3])),
          ],
        ),
      ],
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

    final maxY = (maxRevenue == 0 ? 1000.0 : maxRevenue * 1.2)
        .clamp(1000.0, 10000000.0)
        .toDouble();

    final weeklyFull = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final weeklyShort = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dailyFull = ['10:00 AM','11:00 AM','12:00 PM','1:00 PM','2:00 PM','3:00 PM','4:00 PM','5:00 PM','6:00 PM','7:00 PM','8:00 PM'];
    final dailyShort = ['10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00','20:00'];

    String bottomLabel(int i) {
      if (_selectedPeriod == 'Weekly') return i < weeklyShort.length ? weeklyShort[i] : 'D${i+1}';
      if (_selectedPeriod == 'Daily') return i < dailyShort.length ? dailyShort[i] : '${i+10}:00';
      return i < dayLabels.length ? dayLabels[i] : 'M${i+1}';
    }

    String tooltipLabel(int i) {
      if (_selectedPeriod == 'Weekly') return i < weeklyFull.length ? weeklyFull[i] : 'Day ${i+1}';
      if (_selectedPeriod == 'Daily') return i < dailyFull.length ? dailyFull[i] : '${i+1}:00';
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
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
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
                      'Revenue Analytics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedPeriod == 'Weekly'
                          ? 'This week\'s revenue overview'
                          : _selectedPeriod == 'Daily'
                              ? 'Today\'s hourly revenue'
                              : _selectedPeriod == 'Monthly'
                                  ? 'Monthly revenue breakdown'
                                  : 'Annual revenue trend',
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
          const SizedBox(height: AppTheme.lg),
          SizedBox(
            height: 240,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              margin: EdgeInsets.zero,
              tooltipBehavior: TooltipBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                shouldAlwaysShow: false,
                builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                  final _RevenueData item = data;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tooltipLabel(pointIndex),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatNumber(item.value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
                  color: AppTheme.mediumGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                labelStyle: const TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                numberFormat: NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH'),
                majorGridLines: MajorGridLines(
                  color: const Color(0xFFF0E8E8).withOpacity(0.8),
                  width: 1,
                ),
                maximum: maxY,
              ),
              series: <CartesianSeries<_RevenueData, String>>[
                SplineAreaSeries<_RevenueData, String>(
                  dataSource: chartData,
                  xValueMapper: (_RevenueData data, _) => data.label,
                  yValueMapper: (_RevenueData data, _) => data.value,
                  name: 'Revenue',
                  enableTooltip: true,
                  animationDuration: 0,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.3),
                      AppTheme.primaryLight.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderColor: AppTheme.primaryColor,
                  borderWidth: 3.5,
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
                      final _RevenueData item = data;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          NumberFormat.compactSimpleCurrency(name: '₱', locale: 'en_PH').format(item.value),
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
    );
  }

  // ── Venue Status ──────────────────────────────────────────────────────────

  Widget _buildVenueStatus(BuildContext context) {
    // Determine status based on current time and today's events

    final venueStatus = _getVenueStatus();

    final isReserved = venueStatus['isReserved'] as bool;

    final statusText = venueStatus['statusText'] as String;

    final subtitleText = venueStatus['subtitleText'] as String;

    final statusColor = venueStatus['statusColor'] as Color;

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Collapsible Header
          GestureDetector(
            onTap: () {
              setState(() {
                _isVenueStatusExpanded = !(_isVenueStatusExpanded ?? true);
              });
            },

            child: Container(
              padding: const EdgeInsets.all(AppTheme.md),

              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withOpacity(0.5),

                borderRadius: BorderRadius.circular(8),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Row(
                    children: [
                      Text(
                        'Venue Status',

                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,

                          color: AppTheme.darkGrey,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Compact Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,

                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),

                          borderRadius: BorderRadius.circular(20),

                          border: Border.all(color: statusColor, width: 1),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Container(
                              width: 8,

                              height: 8,

                              decoration: BoxDecoration(
                                color: statusColor,

                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 6),

                            Text(
                              statusText,

                              style: TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.bold,

                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Expand/Collapse Icon
                  Container(
                    padding: const EdgeInsets.all(8),

                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),

                      borderRadius: BorderRadius.circular(6),
                    ),

                    child: Icon(
                      (_isVenueStatusExpanded ?? true)
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,

                      color: AppTheme.primaryColor,

                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isVenueStatusExpanded ?? true) ...[
            const SizedBox(height: AppTheme.md),

            // Next Event Countdown (Moved here)
            if (_nextEvent.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.lg),

                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),

                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),

                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),

                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: AppTheme.lg),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'NEXT EVENT STARTS IN',

                            style: TextStyle(
                              fontSize: 12,

                              fontWeight: FontWeight.bold,

                              color: AppTheme.primaryColor,

                              letterSpacing: 1.0,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _nextEventCountdown,

                            style: const TextStyle(
                              fontSize: 24,

                              fontWeight: FontWeight.bold,

                              color: AppTheme.darkGrey,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${_nextEvent['event_type']} · ${_nextEvent['customer_name']}',

                            style: TextStyle(
                              fontSize: 12,

                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,

                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: _getEventStatusColor(
                          _nextEvent,
                        ).withOpacity(0.1),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        _getEventStatusText(_nextEvent),

                        style: TextStyle(
                          fontSize: 10,

                          fontWeight: FontWeight.bold,

                          color: _getEventStatusColor(_nextEvent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.lg),
            ],

            // 1. Current Status Circle Chart (Restored)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),

              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withOpacity(0.3),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Column(
                children: [
                  SizedBox(
                    height: 180,

                    child: Stack(
                      alignment: Alignment.center,

                      children: [
                        SfCircularChart(
                          margin: EdgeInsets.zero,
                          series: <CircularSeries<_PieData, String>>[
                            DoughnutSeries<_PieData, String>(
                              dataSource: [
                                _PieData('Reserved', isReserved ? 100 : 0, isReserved ? statusColor : AppTheme.backgroundColor),
                                _PieData('Available', isReserved ? 0 : 100, isReserved ? AppTheme.backgroundColor : statusColor.withOpacity(0.1)),
                              ],
                              xValueMapper: (_PieData data, _) => data.x,
                              yValueMapper: (_PieData data, _) => data.y,
                              pointColorMapper: (_PieData data, _) => data.color,
                              innerRadius: '80%',
                              radius: '100%',
                              startAngle: 270,
                              endAngle: 630,
                            ),
                          ],
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Text(
                              statusText,

                              style: TextStyle(
                                fontSize: 22,

                                fontWeight: FontWeight.bold,

                                color: statusColor,

                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),

                              child: Text(
                                subtitleText,

                                textAlign: TextAlign.center,

                                style: const TextStyle(
                                  fontSize: 9,

                                  color: AppTheme.mediumGrey,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.lg),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.xl,
                    ),

                    child: _statusLegendRow(
                      statusColor,

                      isReserved ? 'Venue Occupied' : 'Venue Available',

                      isReserved ? 'Currently in use' : 'Ready for bookings',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.lg),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        // Monthly Header / Dropdown Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Monthly Schedule',

                  style: TextStyle(
                    fontWeight: FontWeight.bold,

                    fontSize: 14,

                    color: AppTheme.darkGrey,

                    letterSpacing: -0.2,
                  ),
                ),

                Text(
                  'All events in ${DateFormat('MMMM yyyy').format(focusedMonth)}',

                  style: const TextStyle(
                    fontSize: 10,

                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),

            _buildMonthDropdown(focusedMonth),
          ],
        ),

        const SizedBox(height: AppTheme.lg),

        // Month-Wide Event List
        _buildEventScheduleList(context),
      ],
    );
  }

  // ── Event Schedule List Widget ─────────────────────────────────────

  Widget _buildEventScheduleList(BuildContext context) {
    _focusedMonth ??= DateTime.now();

    final focusedMonth = _focusedMonth!;

    final now = DateTime.now();

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final targetMonthStr = DateFormat('yyyy-MM').format(focusedMonth);

    // Aggregating all events for the selected month

    List<Map<String, dynamic>> monthEvents = [];

    _eventsByDate.forEach((dateKey, events) {
      if (dateKey.startsWith(targetMonthStr)) {
        for (var e in events) {
          monthEvents.add({
            ...e,

            'date_key': dateKey, // Store the date for sorting
          });
        }
      }
    });

    // Sorting logic (Keep existing sorting)

    monthEvents.sort((a, b) {
      int dateCompare = a['date_key'].compareTo(b['date_key']);

      if (dateCompare != 0) return dateCompare;

      DateTime? startA = a['event_start'] as DateTime?;

      DateTime? startB = b['event_start'] as DateTime?;

      if (startA != null && startB != null) {
        return startA.compareTo(startB);
      }

      String timeA = a['start_time']?.toString() ?? '';

      String timeB = b['start_time']?.toString() ?? '';

      return timeA.compareTo(timeB);
    });

    // Pagination Logic

    final totalItems = monthEvents.length;

    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_schedulePage >= totalPages && totalPages > 0) {
      _schedulePage = totalPages - 1;
    }

    final startIndex = _schedulePage * _itemsPerPage;

    final endIndex = min(startIndex + _itemsPerPage, totalItems);

    final displayedEvents = totalItems > 0
        ? monthEvents.sublist(startIndex, endIndex)
        : [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppTheme.lightGrey),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),

            blurRadius: 10,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.lightGrey)),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.event_note,

                  color: AppTheme.primaryColor,

                  size: 20,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Event Queue - ${DateFormat('MMMM yyyy').format(focusedMonth)}',

                    style: TextStyle(
                      fontWeight: FontWeight.bold,

                      color: AppTheme.darkGrey,

                      fontSize: 14,
                    ),
                  ),
                ),

                Badge(
                  label: Text('${monthEvents.length}'),

                  backgroundColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),

          if (monthEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTheme.xl),

              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,

                      color: AppTheme.mediumGrey.withOpacity(0.5),

                      size: 40,
                    ),

                    const SizedBox(height: AppTheme.md),

                    Text(
                      'No events scheduled for this month.',

                      style: TextStyle(
                        color: AppTheme.mediumGrey,

                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: displayedEvents.length,

              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppTheme.lightGrey),

              itemBuilder: (context, index) {
                final event = displayedEvents[index];

                final dateKey = event['date_key'] as String;

                final isConfirmed =
                    (event['status']?.toString().toLowerCase() ?? '') ==
                    'confirmed';

                final isToday = dateKey == todayStr;

                // Parse date for display

                String displayDate = '';

                try {
                  displayDate = DateFormat(
                    'MMM d',
                  ).format(DateTime.parse(dateKey));
                } catch (e) {
                  displayDate = dateKey;
                }

                return Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.primaryColor.withOpacity(0.02)
                        : null,
                  ),

                  child: Row(
                    children: [
                      // Date Badge
                      Container(
                        width: 45,

                        padding: const EdgeInsets.symmetric(vertical: 4),

                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.primaryColor
                              : AppTheme.backgroundColor,

                          borderRadius: BorderRadius.circular(8),
                        ),

                        child: Column(
                          children: [
                            Text(
                              displayDate.split(' ')[0],

                              style: TextStyle(
                                fontSize: 9,

                                fontWeight: FontWeight.bold,

                                color: isToday
                                    ? Colors.white
                                    : AppTheme.mediumGrey,
                              ),
                            ),

                            Text(
                              displayDate.split(' ')[1],

                              style: TextStyle(
                                fontSize: 13,

                                fontWeight: FontWeight.bold,

                                color: isToday
                                    ? Colors.white
                                    : AppTheme.darkGrey,
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
                            Text(
                              event['event_type'] ?? 'Event',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 13,

                                color: AppTheme.darkGrey,
                              ),
                            ),

                            Row(
                              children: [
                                Icon(
                                  Icons.person,

                                  size: 10,

                                  color: AppTheme.mediumGrey,
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  event['customer_name'] ?? 'Guest',

                                  style: TextStyle(
                                    fontSize: 11,

                                    color: AppTheme.mediumGrey,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Icon(
                                  Icons.access_time,

                                  size: 10,

                                  color: AppTheme.mediumGrey,
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  event['start_time'] ?? 'Time',

                                  style: TextStyle(
                                    fontSize: 11,

                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Icon
                      Icon(
                        isConfirmed ? Icons.check_circle : Icons.pending,

                        size: 16,

                        color: isConfirmed
                            ? AppTheme.successGreen
                            : Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Pagination Controls
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),

                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.lightGrey)),

                  color: Color(0xFFF9FAFB),

                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),

                    bottomRight: Radius.circular(12),
                  ),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Text(
                      'Page ${_schedulePage + 1} of $totalPages',

                      style: const TextStyle(
                        fontSize: 11,

                        color: AppTheme.mediumGrey,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Row(
                      children: [
                        IconButton(
                          onPressed: _schedulePage > 0
                              ? () => setState(() => _schedulePage--)
                              : null,

                          icon: const Icon(Icons.chevron_left),

                          iconSize: 20,

                          padding: EdgeInsets.zero,

                          constraints: const BoxConstraints(),

                          color: AppTheme.primaryColor,
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          onPressed: _schedulePage < totalPages - 1
                              ? () => setState(() => _schedulePage++)
                              : null,

                          icon: const Icon(Icons.chevron_right),

                          iconSize: 20,

                          padding: EdgeInsets.zero,

                          constraints: const BoxConstraints(),

                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusLegendRow(Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,

          height: 36,

          decoration: BoxDecoration(
            color: color.withOpacity(0.1),

            shape: BoxShape.circle,
          ),

          child: Icon(
            title.contains('Occupied')
                ? Icons.event_busy
                : Icons.event_available,

            color: color,

            size: 18,
          ),
        ),

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              title,

              style: const TextStyle(
                fontWeight: FontWeight.bold,

                fontSize: 13,

                color: AppTheme.darkGrey,
              ),
            ),

            Text(
              subtitle,

              style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
            ),
          ],
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              Text(
                'Operations Monitor',

                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,

                  color: AppTheme.darkGrey,
                ),
              ),

              const SizedBox(width: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(4),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Container(
                      width: 6,

                      height: 6,

                      decoration: const BoxDecoration(
                        color: Colors.red,

                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 4),

                    const Text(
                      'REAL-TIME',

                      style: TextStyle(
                        color: Colors.red,

                        fontSize: 10,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildGridCard(
                  'Pending',

                  _pendingOrders.toString(),

                  type: 0,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildGridCard(
                  'In Prep',

                  _preparingOrders.toString(),

                  type: 1,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildGridCard(
                  'Ready',

                  _readyOrders.toString(),

                  type: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildGridCard(
                  'Out of Stock',

                  _outOfStock.toString(),

                  type: 2,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildGridCard(
                  'Low Stock',

                  _lowStock.toString(),

                  type: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(String label, String value, {required int type}) {
    // type: 0 = Normal, 1 = In Prep, 2 = Out of Stock, 3 = More

    Color bgColor = const Color(0xFFF9FAFB); // Soft light grey

    Color labelColor = const Color(0xFF64748B); // Slate 500

    Color valueColor = const Color(0xFF0F172A); // Slate 900

    if (type == 2) {
      bgColor = const Color(0xFFFDECEE); // Light red

      labelColor = const Color(0xFFB71C1C);

      valueColor = const Color(0xFFB71C1C);
    }

    return Container(
      height: 90,

      decoration: BoxDecoration(
        color: bgColor,

        borderRadius: BorderRadius.circular(8),
      ),

      clipBehavior: Clip.antiAlias,

      child: Stack(
        children: [
          if (type == 1)
            Positioned(
              left: 0,

              top: 0,

              bottom: 0,

              child: Container(
                width: 4,

                color: const Color(0xFF14536E),
              ), // Dark teal accent line
            ),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  label,

                  style: TextStyle(
                    fontSize: 13,

                    fontWeight: FontWeight.w500,

                    color: labelColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value.padLeft(2, '0'), // formats 8 -> 08

                  style: TextStyle(
                    fontSize: 26,

                    fontWeight: FontWeight.w800,

                    color: valueColor,

                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                'Recent Activity',

                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,

                  color: AppTheme.darkGrey,
                ),
              ),

              Text(
                'View All Activity',

                style: TextStyle(
                  color: AppTheme.primaryColor,

                  fontSize: 12,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.xl),

          if (_recentActivity.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),

                child: Text('No recent activity'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: min(_recentActivity.length, 5),

              separatorBuilder: (_, _) => const SizedBox(height: 16),

              itemBuilder: (context, index) =>
                  _ActivityTile(item: _recentActivity[index]),
            ),
        ],
      ),
    );
  }

  // ── Confirmed Events Analytics Widget ─────────────────────────────────────

  Widget _buildConfirmedEventsAnalytics(BuildContext context, bool isWide) {
    if (_eventTypeDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.xl),

        decoration: _cardDecoration(),

        child: Column(
          children: [
            Icon(
              Icons.event_busy,

              color: AppTheme.mediumGrey.withOpacity(0.5),

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
                                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
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
                                  color: const Color(0xFF1E293B),
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
                            axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
                          ),
                          primaryYAxis: NumericAxis(
                            axisLine: const AxisLine(width: 0),
                            labelStyle: const TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            majorGridLines: MajorGridLines(
                              color: const Color(0xFFF0E8E8).withOpacity(0.8),
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
                                  AppTheme.primaryColor.withOpacity(0.3),
                                  AppTheme.primaryLight.withOpacity(0.1),
                                  AppTheme.primaryColor.withOpacity(0.0),
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
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
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
                              color: AppTheme.primaryColor,

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

                                        color: AppTheme.primaryColor,
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
                              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
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
                                color: const Color(0xFF1E293B),
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
                          axisLine: const AxisLine(width: 1, color: Color(0xFFEEE0E0)),
                        ),
                        primaryYAxis: NumericAxis(
                          axisLine: const AxisLine(width: 0),
                          labelStyle: const TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          majorGridLines: MajorGridLines(
                            color: const Color(0xFFF0E8E8).withOpacity(0.8),
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
                                AppTheme.primaryColor.withOpacity(0.3),
                                AppTheme.primaryLight.withOpacity(0.1),
                                AppTheme.primaryColor.withOpacity(0.0),
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
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
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
                            color: AppTheme.primaryColor,

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

                                      color: AppTheme.primaryColor,
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
                  color: AppTheme.primaryColor,
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
                    color: Colors.green.withOpacity(0.1),
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
                      color: AppTheme.mediumGrey.withOpacity(0.4),
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
        color: statusColor.withOpacity(0.05),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: statusColor.withOpacity(0.2)),
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
            color: AppTheme.successGreen.withOpacity(0.3),

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
              color: Colors.white.withOpacity(0.2),

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
        color: AppTheme.infoBlue,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: AppTheme.infoBlue.withOpacity(0.3),

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
              color: Colors.white.withOpacity(0.2),

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

  // ── Period Selector Widget ───────────────────────────────────────────────

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),

      child: DropdownButton<String>(
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

        onChanged: (v) => setState(() => _selectedPeriod = v!),
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

class _KpiData {
  final String label;

  final String value;

  final IconData icon;

  final Color color;

  final String sub;

  final bool? subPositive; // null = neutral

  final bool isHighlight;

  final bool showProgress;

  final String? extra;

  const _KpiData({
    required this.label,

    required this.value,

    required this.icon,

    required this.color,

    required this.sub,

    required this.subPositive,

    this.isHighlight = false,

    this.showProgress = false,

    this.extra,
  });
}

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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatefulWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isHighlight) return _buildHighlightCard();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),

      onExit: (_) => setState(() => _isHovered = false),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        curve: Curves.easeOutCubic,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: AppTheme.white,

          borderRadius: BorderRadius.circular(AppTheme.radiusLg),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.02),

              blurRadius: _isHovered ? 20 : 10,

              offset: Offset(0, _isHovered ? 8 : 4),
            ),

            if (_isHovered)
              BoxShadow(
                color: widget.data.color.withOpacity(0.1),

                blurRadius: 30,

                offset: const Offset(0, 0),
              ),
          ],

          border: Border.all(
            color: widget.data.color.withValues(alpha: _isHovered ? 0.3 : 0.0),

            width: 1,
          ),
        ),

        margin: EdgeInsets.only(
          top: _isHovered ? 2.0 : 0.0,

          bottom: _isHovered ? 0.0 : 2.0,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(
                    color: widget.data.color.withValues(
                      alpha: _isHovered ? 0.2 : 0.1,
                    ),

                    borderRadius: BorderRadius.circular(10),

                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: widget.data.color.withOpacity(0.2),

                              blurRadius: 8,

                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),

                  child: Icon(
                    widget.data.icon,

                    color: widget.data.color,

                    size: 20,
                  ),
                ),

                if (widget.data.subPositive != null ||
                    !widget.data.showProgress)
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),

                    style: TextStyle(
                      color: widget.data.sub == 'High'
                          ? AppTheme.errorRed
                          : (widget.data.subPositive == true
                                ? AppTheme.successGreen
                                : AppTheme.mediumGrey),

                      fontSize: _isHovered ? 13 : 12,

                      fontWeight: _isHovered
                          ? FontWeight.w800
                          : FontWeight.bold,
                    ),

                    child: Text(widget.data.sub),
                  ),
              ],
            ),

            const SizedBox(height: AppTheme.lg),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),

              style: const TextStyle(
                color: AppTheme.mediumGrey,

                fontSize: 11,

                fontWeight: FontWeight.bold,

                letterSpacing: 0.5,
              ),

              child: Text(
                widget.data.label,

                overflow: TextOverflow.ellipsis,

                maxLines: 1,
              ),
            ),

            const SizedBox(height: 4),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),

              style: TextStyle(
                fontSize: _isHovered ? 22 : 20,

                fontWeight: FontWeight.w900,

                color: AppTheme.darkGrey,

                letterSpacing: _isHovered ? -1.2 : -1,
              ),

              child: FittedBox(
                fit: BoxFit.scaleDown,

                alignment: Alignment.centerLeft,

                child: Text(widget.data.value),
              ),
            ),

            const SizedBox(height: AppTheme.md),

            if (widget.data.showProgress)
              _buildProgressBar()
            else if (widget.data.extra != null)
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),

                style: TextStyle(
                  color: AppTheme.mediumGrey,

                  fontSize: _isHovered ? 11 : 10,

                  fontWeight: FontWeight.w500,
                ),

                child: Text(widget.data.extra!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightCard() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),

      onExit: (_) => setState(() => _isHovered = false),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        curve: Curves.easeOutCubic,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: AppTheme.primaryColor,

          borderRadius: BorderRadius.circular(AppTheme.radiusLg),

          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(
                alpha: _isHovered ? 0.5 : 0.3,
              ),

              blurRadius: _isHovered ? 25 : 15,

              offset: Offset(0, _isHovered ? 10 : 6),
            ),

            if (_isHovered)
              BoxShadow(
                color: Colors.white.withOpacity(0.2),

                blurRadius: 40,

                offset: const Offset(0, 0),
              ),
          ],

          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: _isHovered
                ? [
                    AppTheme.primaryColor,

                    AppTheme.primaryDark,

                    Colors.white.withOpacity(0.1),
                  ]
                : [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),

        margin: EdgeInsets.only(
          top: _isHovered ? 3.0 : 0.0,

          bottom: _isHovered ? 0.0 : 3.0,
        ),

        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),

                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: _isHovered ? 0.9 : 0.7,
                    ),

                    fontSize: _isHovered ? 12 : 11,

                    fontWeight: FontWeight.bold,

                    letterSpacing: 0.5,
                  ),

                  child: Text(
                    widget.data.label,

                    overflow: TextOverflow.ellipsis,

                    maxLines: 1,
                  ),
                ),

                const SizedBox(height: 8),

                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),

                  style: TextStyle(
                    fontSize: _isHovered ? 22 : 20,

                    fontWeight: FontWeight.w900,

                    color: Colors.white,

                    letterSpacing: _isHovered ? -1.2 : -1,
                  ),

                  child: FittedBox(
                    fit: BoxFit.scaleDown,

                    alignment: Alignment.centerLeft,

                    child: Text(widget.data.value),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),

                      padding: const EdgeInsets.all(4),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: _isHovered ? 0.2 : 0.1,
                        ),

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Icon(
                        Icons.trending_up,

                        color: Colors.white.withValues(
                          alpha: _isHovered ? 0.9 : 0.7,
                        ),

                        size: _isHovered ? 16 : 14,
                      ),
                    ),

                    const SizedBox(width: 8),

                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),

                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: _isHovered ? 0.9 : 0.7,
                        ),

                        fontSize: _isHovered ? 13 : 12,

                        fontWeight: FontWeight.w500,
                      ),

                      child: Text(widget.data.sub),
                    ),
                  ],
                ),
              ],
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),

              right: _isHovered ? -5 : 0,

              top: _isHovered ? -5 : 0,

              child: Icon(
                Icons.restaurant,

                color: Colors.white.withValues(alpha: _isHovered ? 0.3 : 0.2),

                size: _isHovered ? 52 : 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),

          height: _isHovered ? 6 : 4,

          width: double.infinity,

          decoration: BoxDecoration(
            color: AppTheme.lightGrey,

            borderRadius: BorderRadius.circular(_isHovered ? 3 : 2),

            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.data.color.withOpacity(0.2),

                      blurRadius: 4,

                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),

          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,

            widthFactor: _isHovered ? 0.75 : 0.65,

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),

              decoration: BoxDecoration(
                color: widget.data.color,

                borderRadius: BorderRadius.circular(_isHovered ? 3 : 2),

                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.data.color.withOpacity(0.4),

                          blurRadius: 6,

                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),

          width: 8,

          height: 8,

          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    item.title,

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      fontSize: 14,

                      color: AppTheme.darkGrey,
                    ),
                  ),

                  Text(
                    item.time,

                    style: const TextStyle(
                      fontSize: 11,

                      color: AppTheme.mediumGrey,

                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 2),

              Text(
                item.subtitle,

                style: const TextStyle(
                  fontSize: 13,

                  color: AppTheme.mediumGrey,

                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
            color: color.withOpacity(0.15),
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
