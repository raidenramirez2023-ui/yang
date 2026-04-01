import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
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

  final _supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _ordersStream;
  late Stream<List<Map<String, dynamic>>> _inventoryStream;
  late Stream<List<Map<String, dynamic>>> _reservationsStream;

  // ── KPI data (now derived from streams) ──────────────────────────────────
  double _dailyRevenue = 0.0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _reservations = 0;
  int _pendingReservations = 0;
  List<double> _weeklyRevenue = List.filled(7, 0.0);
  int _pendingOrders = 0;
  int _preparingOrders = 0;
  int _readyOrders = 0;
  int _outOfStock = 0;
  int _lowStock = 0;
  double _revenueGrowth = 0.0;
  double _orderGrowth = 0.0;
  double _customerGrowth = 0.0;

  // ── Recent activity (now derived from streams) ───────────────────────────
  List<_ActivityItem> _recentActivity = [];
  DateTime? _lastUpdated;
  int _previousOrderCount = 0;
  bool? _showNewOrderNotification;
  String _newOrderAmount = '';
  
  // ── Real-time event conflict detection ───────────────────────────────
  Map<String, List<Map<String, dynamic>>> _eventsByDate = {};
  List<String> _conflictDates = [];
  bool? _showConflictNotification;
  String _newConflictDate = '';
  
  // ── Real-time reservation tracking ───────────────────────────────
  int _previousReservationCount = 0;
  bool? _showNewReservationNotification;
  String _newReservationInfo = '';
  
  // ── UI State Variables ───────────────────────────────────────────────
  bool? _isVenueStatusExpanded; // Start expanded by default
  DateTime? _focusedMonth;
  DateTime? _selectedDate;
  bool? _isCalendarGridExpanded;
  String _selectedPeriod = 'Weekly'; // New period selector state
  String _selectedYear = '2026'; // New year selector state

  @override
  void initState() {
    super.initState();
    
    // Initialize state variables
    _isVenueStatusExpanded = true;
    _isCalendarGridExpanded = false;
    _showNewOrderNotification = false;
    _showConflictNotification = false;
    _showNewReservationNotification = false;
    _focusedMonth = DateTime.now();
    _selectedDate = DateTime.now();
    
    // Enhanced real-time streams with immediate updates
    _ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((events) => events.map((order) {
          // Ensure all order data is properly loaded
          return {
            ...order,
            'total_amount': order['total_amount'] ?? 0.0,
            'created_at': order['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'customer_name': order['customer_name'] ?? 'Guest',
            'transaction_id': order['transaction_id'] ?? order['id'],
          };
        }).toList());
        
    _inventoryStream = _supabase.from('inventory').stream(primaryKey: ['id']);
    _reservationsStream = _supabase.from('reservations').stream(primaryKey: ['id']).order('created_at', ascending: false);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _processData(
    List<Map<String, dynamic>> allOrders, 
    List<Map<String, dynamic>> allInventory,
    List<Map<String, dynamic>> allReservations,
  ) {
    // Check for new orders (real-time detection)
    final currentOrderCount = allOrders.length;
    if (_previousOrderCount > 0 && currentOrderCount > _previousOrderCount) {
      // New order detected!
      final newOrders = allOrders.take(currentOrderCount - _previousOrderCount).toList();
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
    if (_previousReservationCount > 0 && currentReservationCount > _previousReservationCount) {
      // New reservation detected!
      final newReservations = allReservations.take(currentReservationCount - _previousReservationCount).toList();
      for (var newReservation in newReservations) {
        final customerName = newReservation['customer_name'] ?? 'Guest';
        final eventType = newReservation['event_type'] ?? 'Event';
        final eventDate = newReservation['event_date'] ?? 'Unknown';
        final startTime = newReservation['start_time'] ?? 'Unknown';
        
        _newReservationInfo = '$customerName booked $eventType on $eventDate at $startTime';
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
    
    // Get ALL orders for today (comprehensive daily revenue)
    final todayOrders = allOrders.where((o) {
      final createdAt = o['created_at']?.toString() ?? '';
      return createdAt.startsWith(todayStr);
    }).toList();
    
    // Calculate total daily revenue from ALL orders today (preserve decimal values)
    _dailyRevenue = todayOrders.fold(0.0, (sum, o) {
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
    _totalOrders = todayOrders.length;
    
    Set<String> uniqueCustomers = {};
    for (var o in todayOrders) {
      uniqueCustomers.add(o['customer_name'] ?? 'Guest');
    }
    _totalCustomers = uniqueCustomers.length;
    
    // Reservations (Events) - Count all active confirmed and pending reservations
    final confirmedReservations = allReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == 'confirmed';
    }).toList();
    _reservations = confirmedReservations.length;

    final pendingReservations = allReservations.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == 'pending';
    }).toList();
    _pendingReservations = pendingReservations.length;

    // Weekly Revenue Calculation
    _weeklyRevenue = _processChartData(allOrders);

    // Kitchen Status Counts (Real-time from today's orders)
    _pendingOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? 'Pending') == 'Pending').length;
    _preparingOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? '') == 'Preparing').length;
    _readyOrders = todayOrders.where((o) => (o['kitchen_status']?.toString() ?? '') == 'Ready').length;
    
    // Growth Calculations (vs Yesterday) - Compare total daily revenue
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    
    // Get ALL orders from yesterday for accurate comparison
    final yesterdayOrders = allOrders.where((o) {
      final createdAt = o['created_at']?.toString() ?? '';
      return createdAt.startsWith(yesterdayStr);
    }).toList();
    
    final yesterdayRevenue = yesterdayOrders.fold(0.0, (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0.0));
    final yesterdayOrdersCount = yesterdayOrders.length;
    
    if (yesterdayRevenue > 0) {
      _revenueGrowth = ((_dailyRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
    } else {
      _revenueGrowth = _dailyRevenue > 0 ? 100.0 : 0.0;
    }

    if (yesterdayOrdersCount > 0) {
      _orderGrowth = ((_totalOrders - yesterdayOrdersCount) / yesterdayOrdersCount) * 100;
    } else {
      _orderGrowth = _totalOrders > 0 ? 100.0 : 0.0;
    }
    
    Set<String> yesterdayCustomers = {};
    for (var o in yesterdayOrders) {
      yesterdayCustomers.add(o['customer_name'] ?? 'Guest');
    }
    if (yesterdayCustomers.isNotEmpty) {
      _customerGrowth = ((_totalCustomers - yesterdayCustomers.length) / yesterdayCustomers.length) * 100;
    } else {
      _customerGrowth = _totalCustomers > 0 ? 100.0 : 0.0;
    }

    // Inventory Alerts (Real-time)
    _outOfStock = allInventory.where((i) => ((i['quantity'] as num?)?.toInt() ?? 0) == 0).length;
    _lowStock = allInventory.where((i) {
      final q = (i['quantity'] as num?)?.toInt() ?? 0;
      return q > 0 && q < 10;
    }).length;

    _lastUpdated = DateTime.now();
    // Update Recent Activity
    _updateActivity(todayOrders, allInventory, allReservations);
  }

  void _processEventConflicts(List<Map<String, dynamic>> allReservations) {
    // Clear previous conflicts
    _eventsByDate.clear();
    _conflictDates.clear();

    // Group confirmed reservations by date and time
    Map<String, List<Map<String, dynamic>>> eventsByDateTime = {};
    
    for (var reservation in allReservations) {
      if (reservation['status'] == 'confirmed' || reservation['status'] == 'pending') {
        final eventDate = reservation['event_date']?.toString();
        if (eventDate != null) {
          // Parse start time and calculate end time
          DateTime eventStart;
          DateTime eventEnd;
          
          try {
            final startTime = reservation['start_time']?.toString() ?? '10:00 AM';
            final durationHours = (reservation['duration_hours'] as num?)?.toDouble() ?? 4.0;
            
            // Parse start time
            if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
              DateTime parsedTime = DateFormat.jm().parse(startTime.trim());
              final parsedDate = DateTime.parse(eventDate);
              eventStart = DateTime(
                parsedDate.year, parsedDate.month, parsedDate.day, 
                parsedTime.hour, parsedTime.minute
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
            
            if (event1['event_start'] != null && event2['event_start'] != null) {
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
                  
                  // Show conflict notification with priority info
                  _showConflictNotification = true;
                  _newConflictDate = '${DateFormat('MMM dd').format(start1)}: ${event1['customer_name']} (priority) vs ${event2['customer_name']}';
                  
                  // Auto-hide notification after 8 seconds
                  Future.delayed(const Duration(seconds: 8), () {
                    if (mounted) {
                      setState(() {
                        _showConflictNotification = false;
                      });
                    }
                  });
                }
                break;
              }
            }
          }
        }
      }
    }
  }

  bool _isReservationOngoing(Map<String, dynamic> r) {
    try {
      final now = DateTime.now();
      final eventDate = r['event_date']?.toString();
      final startTime = r['start_time']?.toString();
      if (eventDate == null || startTime == null) return false;

      DateTime eventStart;
      if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
        DateTime parsedTime;
        try {
          parsedTime = DateFormat.jm().parse(startTime.trim());
        } catch (e) {
          String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
          parsedTime = DateFormat.jm().parse(fixedTime);
        }
        final parsedDate = DateTime.parse(eventDate);
        eventStart = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
      } else {
        String timeStr = startTime;
        if (timeStr.length == 5) timeStr = '$timeStr:00';
        eventStart = DateTime.parse('${eventDate}T$timeStr');
      }

      final durationValue = r['duration_hours'];
      int durationHours = 4; // Default
      if (durationValue is int) {
        durationHours = durationValue;
      } else if (durationValue is String) {
        durationHours = int.tryParse(durationValue) ?? 4;
      }

      final eventEnd = eventStart.add(Duration(hours: durationHours));
      
      // An event is "ongoing" if current time is after start AND before end.
      // However, usually we show it as "ongoing" even if it hasn't started yet but is today.
      // The user said "mawawala din yung event ongoing kapag tapos na yung event".
      // This implies we show it UNTIL it ends.
      return now.isBefore(eventEnd);
    } catch (_) {
      return true; // Fallback to show it if parsing fails
    }
  }

  List<String> getChartLabels() {
    if (_selectedPeriod == 'Daily') {
      // Business hours only: 10:00 AM to 8:00 PM (10:00 to 20:00)
      return ['10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'];
    } else if (_selectedPeriod == 'Weekly') {
      return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    } else if (_selectedPeriod == 'Monthly') {
      return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    } else {
      // Annual - 2016 to current year (2026)
      return ['2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'];
    }
  }

  List<double> _processChartData(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    Map<int, double> periodData = {};
    
    for (var order in orders) {
      final date = DateTime.tryParse(order['created_at'] ?? '');
      if (date == null) continue;
      
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      
      // Apply period-specific filtering
      switch (_selectedPeriod) {
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
          if (dailyDiff >= 0 && dailyDiff < 7 && date.year.toString() == _selectedYear) {
            final key = date.weekday - 1; // 0 = Monday, 6 = Sunday
            periodData[key] = (periodData[key] ?? 0) + amount;
          }
          break;
        case 'Monthly':
          // All months of selected year
          if (date.year.toString() == _selectedYear) {
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
    if (_selectedPeriod == 'Daily') {
      return List.generate(11, (i) => periodData[i] ?? 0.0); // 11 business hours: 10:00-20:00
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
      final timeStr = time != null ? DateFormat('HH:mm').format(time) : 'Just now';
      
      activities.add(_ActivityItem(
        icon: Icons.receipt_long,
        color: AppTheme.successGreen,
        title: 'Order #${o['transaction_id'] ?? o['id']} Completed',
        subtitle: '${o['customer_name'] ?? 'Guest'} · ₱${o['total_amount']}',
        time: timeStr,
      ));
    }

    // Latest Reservation (show confirmed or recent)
    if (reservations.isNotEmpty) {
      final r = reservations.first;
      final status = r['status']?.toString() ?? 'pending';
      final isConfirmed = status == 'confirmed';
      
      activities.add(_ActivityItem(
        icon: isConfirmed ? Icons.check_circle : Icons.event_available,
        color: isConfirmed ? AppTheme.successGreen : AppTheme.infoBlue,
        title: isConfirmed ? 'Reservation Confirmed' : 'New Reservation',
        subtitle: '${r['customer_name']} · ${r['event_type']}',
        time: 'Just now',
      ));
    }

    // Low Stock Alerts
    final lowStockItems = inventory.where((item) => ((item['quantity'] as num?)?.toInt() ?? 0) < 10).take(2).toList();
    for (var item in lowStockItems) {
      activities.add(_ActivityItem(
        icon: Icons.inventory_2,
        color: AppTheme.warningOrange,
        title: 'Low Stock Alert',
        subtitle: '${item['item_name']} · ${item['quantity']} left',
        time: 'Now',
      ));
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
          stream: _inventoryStream,
          builder: (context, invSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reservationsStream,
              builder: (context, resSnapshot) {
                final allOrders = orderSnapshot.data ?? [];
                final allInventory = invSnapshot.data ?? [];
                final allReservations = resSnapshot.data ?? [];
                
                _processData(allOrders, allInventory, allReservations);

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
                        _buildSectionTitle(context, 'Today\'s Overview'),
                        const SizedBox(height: AppTheme.md),
                        _buildKpiGrid(isDesktop || isTablet),
                        const SizedBox(height: AppTheme.xl),

                        // ── Charts Layout with Centered Venue Status ──────────────────
                        ResponsiveUtils.isMobile(context)
                            ? Column(
                                children: [
                                  _buildRevenueChart(context),
                                  const SizedBox(height: AppTheme.lg),
                                  _buildVenueStatus(context),
                                ],
                              )
                            : (isDesktop || isTablet)
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          children: [
                                            _buildRevenueChart(context),
                                            const SizedBox(height: AppTheme.lg),
                                            _buildVenueStatus(context),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildRevenueChart(context),
                                      const SizedBox(height: AppTheme.lg),
                                      _buildVenueStatus(context),
                                    ],
                                  ),

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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          children: [
                                            _buildOperationsMonitor(context),
                                            const SizedBox(height: AppTheme.lg),
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
                      // Event conflict notification overlay
                      if (_showConflictNotification ?? false)
                        Positioned(
                          top: 140,
                          left: 20,
                          child: _buildConflictNotification(),
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

  // ── KPI Grid ──────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(bool isWide) {
    final cards = [
      _KpiData(
        label: 'DAILY REVENUE',
        value: _formatNumber(_dailyRevenue),
        icon: Icons.payments_rounded,
        color: AppTheme.primaryColor,
        sub: '${_revenueGrowth >= 0 ? '+' : ''}${_revenueGrowth.toStringAsFixed(1)}% from yesterday',
        subPositive: _revenueGrowth >= 0,
        isHighlight: true,
      ),
      _KpiData(
        label: 'TOTAL ORDERS',
        value: '$_totalOrders',
        icon: Icons.shopping_cart_outlined,
        color: AppTheme.infoBlue,
        sub: '${_orderGrowth >= 0 ? '+' : ''}${_orderGrowth.toStringAsFixed(1)}%',
        subPositive: _orderGrowth >= 0,
        showProgress: true,
      ),
      _KpiData(
        label: 'CUSTOMERS TODAY',
        value: '$_totalCustomers',
        icon: Icons.people_outline,
        color: AppTheme.successGreen,
        sub: '${_customerGrowth >= 0 ? '+' : ''}${_customerGrowth.toStringAsFixed(1)}%',
        subPositive: _customerGrowth >= 0,
        extra: 'from yesterday',
      ),
      _KpiData(
        label: 'CONFIRMED EVENTS',
        value: '$_reservations',
        icon: Icons.confirmation_number_outlined,
        color: AppTheme.successGreen,
        sub: '$_pendingReservations Pending',
        subPositive: _pendingReservations > 0,
        extra: 'Total Confirmed',
      ),
    ];

    // Mobile: single column, Tablet: 2x2 grid, Desktop: 4 columns
    if (ResponsiveUtils.isMobile(context)) {
      return Column(
        children: cards
            .map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: _KpiCard(data: d),
                ))
            .toList(),
      );
    }

    if (isWide) {
      return Row(
        children: cards
            .map((d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppTheme.md),
                    child: _KpiCard(data: d),
                  ),
                ))
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

    final maxRevenue = _weeklyRevenue.isEmpty ? 0.0 : _weeklyRevenue.reduce(max);
    // Add 20% headroom for labels and clarity
    final maxY = (maxRevenue == 0 ? 1000.0 : maxRevenue * 1.2)
        .clamp(1000.0, 10000000.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Revenue Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                        letterSpacing: -0.5,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              _periodSelector(),
            ],
          ),
          const SizedBox(height: AppTheme.xxl),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.darkGrey.withValues(alpha: 0.95),
                    tooltipPadding: const EdgeInsets.all(12),
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '₱${_formatNumber(rod.toY.toInt())}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: '\n${dayLabels[group.x]} Performance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        if (value == 0) return const SizedBox.shrink();
                        String label = '';
                        if (value >= 1000000) {
                          label = '${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value >= 1000) {
                          label = '${(value / 1000).toStringAsFixed(0)}k';
                        } else {
                          label = value.toStringAsFixed(0);
                        }
                        return Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          dayLabels[value.toInt() % dayLabels.length],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.lightGrey.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  dayLabels.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyRevenue[i],
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppTheme.backgroundColor,
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
                color: AppTheme.backgroundColor.withValues(alpha: 0.5),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      (_isVenueStatusExpanded ?? true) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
              
              // 1. Current Status Circle Chart (Restored)
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 65,
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  color: isReserved ? statusColor : AppTheme.backgroundColor,
                                  value: isReserved ? 100 : 0,
                                  title: '',
                                  radius: 20,
                                ),
                                PieChartSectionData(
                                  color: isReserved ? AppTheme.backgroundColor : statusColor.withValues(alpha: 0.1),
                                  value: isReserved ? 0 : 100,
                                  title: '',
                                  radius: 15,
                                ),
                              ],
                            ),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
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

              // 2. Month Selector & Event List (Integrated)
              _buildMonthlyOverview(context),
              const SizedBox(height: AppTheme.xl),
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
            'subtitleText': '$customerName - $eventType starting soon ($startTime)',
            'statusColor': AppTheme.primaryColor,
          };
        } else {
          // Not starting yet - stay GREEN/OPEN
          return {
            'isReserved': false,
            'statusText': 'OPEN',
            'subtitleText': 'Next event: $customerName - $eventType at $startTime',
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
    
    // Sorting by date and then by time
    monthEvents.sort((a, b) {
      int dateCompare = a['date_key'].compareTo(b['date_key']);
      if (dateCompare != 0) return dateCompare;
      
      // Secondary sort by event_start if available
      DateTime? startA = a['event_start'] as DateTime?;
      DateTime? startB = b['event_start'] as DateTime?;
      if (startA != null && startB != null) {
        return startA.compareTo(startB);
      }
      
      // Fallback time sort
      String timeA = a['start_time']?.toString() ?? '';
      String timeB = b['start_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                const Icon(Icons.event_note, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Event Queue - ${DateFormat('MMMM yyyy').format(focusedMonth)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey, fontSize: 14),
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
                    Icon(Icons.event_available, color: AppTheme.mediumGrey.withValues(alpha: 0.5), size: 40),
                    const SizedBox(height: AppTheme.md),
                    Text(
                      'No events scheduled for this month.',
                      style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: monthEvents.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.lightGrey),
              itemBuilder: (context, index) {
                final event = monthEvents[index];
                final dateKey = event['date_key'] as String;
                final isConfirmed = (event['status']?.toString().toLowerCase() ?? '') == 'confirmed';
                final isToday = dateKey == todayStr;
                
                // Parse date for display
                String displayDate = '';
                try {
                   displayDate = DateFormat('MMM d').format(DateTime.parse(dateKey));
                } catch (e) {
                   displayDate = dateKey;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.primaryColor.withValues(alpha: 0.02) : null,
                  ),
                  child: Row(
                    children: [
                      // Date Badge
                      Container(
                        width: 45,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.primaryColor : AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              displayDate.split(' ')[0],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : AppTheme.mediumGrey,
                              ),
                            ),
                            Text(
                              displayDate.split(' ')[1],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : AppTheme.darkGrey,
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
                                Icon(Icons.person, size: 10, color: AppTheme.mediumGrey),
                                const SizedBox(width: 4),
                                Text(
                                  event['customer_name'] ?? 'Guest',
                                  style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.access_time, size: 10, color: AppTheme.mediumGrey),
                                const SizedBox(width: 4),
                                Text(
                                  event['start_time'] ?? 'Time',
                                  style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
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
                        color: isConfirmed ? AppTheme.successGreen : Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),
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
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            title.contains('Occupied') ? Icons.event_busy : Icons.event_available,
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
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGrey,
              ),
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
          icon: const Icon(Icons.unfold_more, size: 16, color: AppTheme.mediumGrey),
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
              setState(() => _focusedMonth = newValue);
            }
          },
          items: months.map((date) => DropdownMenuItem<DateTime>(
            value: date,
            child: Text(DateFormat('MMM yyyy').format(date)),
          )).toList(),
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('REAL-TIME', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildGridCard('Pending', _pendingOrders.toString(), type: 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildGridCard('In Prep', _preparingOrders.toString(), type: 1)),
              const SizedBox(width: 12),
              Expanded(child: _buildGridCard('Ready', _readyOrders.toString(), type: 0)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildGridCard('Out of Stock', _outOfStock.toString(), type: 2)),
              const SizedBox(width: 12),
              Expanded(child: _buildGridCard('Low Stock', _lowStock.toString(), type: 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildGridCard('...', '', type: 3)),
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
              child: Container(width: 4, color: const Color(0xFF14536E)), // Dark teal accent line
            ),
          if (type == 3)
            const Center(child: Icon(Icons.more_horiz, color: Colors.grey, size: 28))
          else
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
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No recent activity')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(_recentActivity.length, 5),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _ActivityTile(item: _recentActivity[index]),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
    if (numValue >= 1000000) return '₱${(numValue / 1000000).toStringAsFixed(1)}m';
    if (numValue >= 10000) return '₱${(numValue / 1000).toStringAsFixed(0)}k';
    // For amounts under 10k, show the exact amount with proper formatting
    return '₱${numValue.toStringAsFixed(numValue.truncate() == numValue ? 0 : 1)}';
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
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

  // ── Event Conflict Notification Widget ────────────────────────────────────
  Widget _buildConflictNotification() {
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
              Icons.event_busy,
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
                'EVENT CONFLICT!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Multiple events on $_newConflictDate',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Click to view details',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
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
            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) => setState(() => _selectedPeriod = v!),
      ),
    );
  }
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

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isHighlight) return _buildHighlightCard();

    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              if (data.subPositive != null || !data.showProgress)
                Text(
                  data.sub,
                  style: TextStyle(
                    color: data.sub == 'High' ? AppTheme.errorRed : (data.subPositive == true ? AppTheme.successGreen : AppTheme.mediumGrey),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.xl),
          Text(
            data.label,
            style: const TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          if (data.showProgress)
            _buildProgressBar()
          else if (data.extra != null)
            Text(
              data.extra!,
              style: const TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    data.sub,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.restaurant, color: Colors.white.withValues(alpha: 0.2), size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.65,
            child: Container(
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(2),
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

  _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
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

