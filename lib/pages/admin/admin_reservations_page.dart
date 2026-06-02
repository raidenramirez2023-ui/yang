import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/reservation_service.dart';
import 'package:yang_chow/widgets/price_quotation_dialog.dart';

class AdminReservationsPage extends StatefulWidget {
  final bool isFullscreen;
  const AdminReservationsPage({super.key, this.isFullscreen = false});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, confirmed, completed, cancelled
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  
  // Services
  final ReservationService _reservationService = ReservationService();
  
  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    
    try {
      // Debug: Check current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('Current user metadata: ${currentUser?.userMetadata}');
      
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .order('created_at', ascending: false);

      debugPrint('Reservations loaded: ${response.length}');
      debugPrint('Response: $response');

      // Check for expired reservations and update them
      await _updateExpiredReservations(response);

      setState(() {
        reservations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      
      // If we hit a schema error, try to sync and reload once
      if (e.toString().contains('PGRST204') || e.toString().contains('is_archived')) {
        debugPrint('Detected schema mismatch. Attempting auto-sync...');
        await _ensureSchemaSynchronized(silent: true);
        // Retry load once after sync
        try {
          final retryResponse = await Supabase.instance.client
              .from('reservations')
              .select('*')
              .order('created_at', ascending: false);
          setState(() {
            reservations = List<Map<String, dynamic>>.from(retryResponse);
            _isLoading = false;
          });
          return;
        } catch (_) {}
      }

      setState(() => _isLoading = false);
      _showSnackBar('Error loading reservations: $e', Colors.red);
    }
  }

  Future<void> _ensureSchemaSynchronized({bool silent = false}) async {
    try {
      // 1. Ensure column exists
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;"
      });
      
      // 2. Notify PostgREST to reload schema cache
      await Supabase.instance.client.rpc('exec_sql', params: {
        'sql': "NOTIFY pgrst, 'reload schema';"
      });

      if (!silent) _showSnackBar('Database schema synchronized successfully', Colors.green);
    } catch (e) {
      debugPrint('Manual sync error: $e');
      if (!silent) {
        _showSnackBar('Sync failed. Please ensure you have the "exec_sql" RPC function defined in Supabase.', Colors.orange);
      }
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _updateExpiredReservations(List<Map<String, dynamic>> reservations) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    for (final reservation in reservations) {
      // Target confirmed reservations that are not archived
      final currentStatus = (reservation['status'] ?? '').toString().toLowerCase();
      final isArchived = reservation['is_archived'] == true;
      
      if (currentStatus != 'confirmed' || isArchived) continue;
      
      try {
        final eventDate = reservation['event_date']?.toString() ?? '';
        final startTime = reservation['start_time']?.toString() ?? '';
        
        if (eventDate.isEmpty || startTime.isEmpty) continue;

        // --- RULE 1: If the date is strictly before today, it's finished ---
        if (eventDate.compareTo(todayStr) < 0) {
          await _markAsCompleted(reservation, now);
          continue;
        }

        // --- RULE 2: If the date is today, check the specific time + duration ---
        if (eventDate == todayStr) {
          DateTime? eventDateTime;
          try {
            if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
              DateTime parsedTime;
              try {
                parsedTime = DateFormat.jm().parse(startTime.trim());
              } catch (e) {
                String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
                parsedTime = DateFormat.jm().parse(fixedTime);
              }
              final parsedDate = DateTime.parse(eventDate);
              eventDateTime = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
            } else {
              String timeStr = startTime;
              if (timeStr.length == 8 && timeStr.contains(':')) timeStr = timeStr.substring(0, 5);
              eventDateTime = DateTime.parse('${eventDate}T$timeStr');
            }
          } catch (e) {
            debugPrint('Expiration parsing error for ${reservation['id']}: $e');
          }

          if (eventDateTime != null) {
            final durationValue = reservation['duration_hours'];
            int durationHours = (durationValue is int) ? durationValue : (int.tryParse(durationValue?.toString() ?? '4') ?? 4);
            final expiresAt = eventDateTime.add(Duration(hours: durationHours));
            
            if (now.isAfter(expiresAt)) {
              await _markAsCompleted(reservation, now);
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking reservation expiration: $e');
      }
    }
  }

  Future<void> _markAsCompleted(Map<String, dynamic> reservation, DateTime now) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({
            'status': 'completed',
            'updated_at': now.toIso8601String()
          })
          .eq('id', reservation['id']);
      
      // Update local state immediately
      reservation['status'] = 'completed';
      debugPrint('Reservation ${reservation['id']} auto-completed.');
    } catch (e) {
      debugPrint('Failed to mark reservation as completed in DB: $e');
      // If DB update fails (schema issue), we still mark it locally so the UI looks correct for this session
      reservation['status'] = 'completed';
    }
  }

  Future<void> _archiveReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation archived successfully', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error archiving reservation: $e', Colors.red);
    }
  }

  Future<void> _restoreReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'is_archived': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      _showSnackBar('Reservation restored', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error restoring reservation: $e', Colors.red);
    }
  }

  Future<void> _hardDeleteReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .delete()
          .eq('id', reservationId);

      _showSnackBar('Reservation permanently deleted', Colors.green);
      _loadReservations();
    } catch (e) {
      _showSnackBar('Error deleting reservation: $e', Colors.red);
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus, [Map<String, dynamic>? reservation]) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      // Generate Auto Announcement on Confirm
      if (newStatus == 'confirmed' && reservation != null) {
        final eventDate = reservation['event_date'];
        final startTime = reservation['start_time'];
        
        DateTime eventDateTime;
        try {
          // Attempt to parse date and time combined
          // Handles cases like "HH:mm" or "h:mm a"
          if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
            // Localized format from TimePicker (e.g. "11:43 AM" or "11:43AM")
            DateTime parsedTime;
            try {
              parsedTime = DateFormat.jm().parse(startTime.trim());
            } catch (e) {
              // Try adding a space if missing
              String fixedTime = startTime.toUpperCase().replaceAll('AM', ' AM').replaceAll('PM', ' PM').trim().replaceAll('  ', ' ');
              parsedTime = DateFormat.jm().parse(fixedTime);
            }
            final parsedDate = DateTime.parse(eventDate);
            eventDateTime = DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
              parsedTime.hour,
              parsedTime.minute,
            );
          } else {
            // ISO-ish format (e.g. "11:43" or "11:43:00")
            String timeStr = startTime;
            if (timeStr.length == 5) timeStr = '$timeStr:00';
            eventDateTime = DateTime.parse('${eventDate}T$timeStr');
          }
        } catch (e) {
          debugPrint('Parsing error: $e');
          try {
            eventDateTime = DateTime.parse(eventDate);
          } catch(e) {
            eventDateTime = DateTime.now();
          }
        }
        
        // Get duration (it might be String or int depending on how it's stored)
        final durationValue = reservation['duration_hours'];
        int durationHours = 4; // Default to 4 hours
        if (durationValue != null) {
          if (durationValue is int) {
            durationHours = durationValue;
          } else if (durationValue is String) {
            durationHours = int.tryParse(durationValue) ?? 4;
          }
        }
        
        final expiresAt = eventDateTime.add(Duration(hours: durationHours));

        // Format the time for display
        String displayTime;
        if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
          displayTime = startTime; // Already in 12-hour format
        } else {
          // Convert 24-hour format to 12-hour format
          if (startTime.length == 8 && startTime.contains(':')) {
            // Format: "18:35:00" -> convert to "6:35 PM"
            final hour = int.parse(startTime.substring(0, 2));
            final minute = startTime.substring(3, 5);
            final period = hour >= 12 ? 'PM' : 'AM';
            final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
            displayTime = '$displayHour:$minute $period';
          } else {
            displayTime = startTime; // Fallback to original
          }
        }

        await Supabase.instance.client.from('announcements').insert({
          'title': 'Confirmed Reservation: ${reservation['event_type']}',
          'content': 'We are excited to host ${reservation['customer_name']} and ${reservation['number_of_guests']} guests for a ${reservation['event_type']} on $eventDate at $displayTime.',
          'is_active': true,
          'expires_at': expiresAt.toUtc().toIso8601String(),
        });
      }

      // Send notification to customer
      if (reservation != null) {
        String actionVerb = 'updated';
        if (newStatus == 'confirmed') actionVerb = 'approved';
        if (newStatus == 'cancelled') actionVerb = 'cancelled';
        if (newStatus == 'completed') actionVerb = 'completed';

        await NotificationService.sendNotification(
          recipientEmail: reservation['customer_email'],
          actorName: 'Admin',
          actionType: actionVerb,
          reservationId: reservationId,
          eventType: reservation['event_type'],
          eventDate: reservation['event_date'],
        );
      }

      _showSnackBar('Reservation status updated to $newStatus', Colors.green);
      _loadReservations(); // Refresh the list
    } catch (e) {
      _showSnackBar('Error updating reservation: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredReservations {
    if (_selectedFilter == 'archived') {
      return reservations.where((r) => r['is_archived'] == true).toList();
    }
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    if (_selectedFilter == 'all') return unarchived.toList();
    return unarchived.where((r) => r['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Padding(
      padding: isDesktop 
          ? EdgeInsets.zero 
          : ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with internal padding on desktop
          if (!widget.isFullscreen)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 0,
                vertical: isDesktop ? 16 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Event Reservations',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen, color: AppTheme.primaryColor),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: const Color(0xFFF8F9FA),
                              appBar: AppBar(
                                title: const Text(
                                  'Event Reservations', 
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)
                                ),
                                backgroundColor: Colors.white,
                                elevation: 1,
                                iconTheme: const IconThemeData(color: Colors.black87),
                              ),
                              body: const SafeArea(
                                child: AdminReservationsPage(isFullscreen: true),
                              ),
                            ),
                          ),
                        ).then((_) {
                          _loadReservations();
                        });
                      },
                      tooltip: 'View Full Screen',
                    ),
                  ),
                ],
              ),
            ),
          if (!isDesktop) ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSegmentControl(),
          const SizedBox(height: 20),
          Expanded(child: _buildReservationsTable()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFilterSegmentControl(),
        ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),
        Expanded(
          child: _buildReservationsList(),
        ),
      ],
    );
  }

  Widget _buildFilterSegmentControl() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    final unarchived = reservations.where((r) => r['is_archived'] != true);
    final counts = {
      'all':       unarchived.length,
      'pending':   unarchived.where((r) => r['status'] == 'pending').length,
      'confirmed': unarchived.where((r) => r['status'] == 'confirmed').length,
      'completed': unarchived.where((r) => r['status'] == 'completed').length,
      'cancelled': unarchived.where((r) => r['status'] == 'cancelled').length,
      'archived':  reservations.where((r) => r['is_archived'] == true).length,
    };

    final filters = [
      {'value': 'all', 'label': 'All Events'},
      {'value': 'pending', 'label': 'Pending'},
      {'value': 'confirmed', 'label': 'Confirmed'},
      {'value': 'completed', 'label': 'Completed'},
      {'value': 'cancelled', 'label': 'Cancelled'},
      {'value': 'archived', 'label': 'Archived'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) => _buildSegmentButton(
                  f['value'] as String, 
                  f['label'] as String,
                  count: counts[f['value']] ?? 0,
                )).toList(),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: filters.map((f) => Expanded(
                child: _buildSegmentButton(
                  f['value'] as String, 
                  f['label'] as String,
                  count: counts[f['value']] ?? 0,
                ),
              )).toList(),
            ),
    );
  }

  Widget _buildSegmentButton(String value, String label, {int count = 0}) {
    final isSelected = _selectedFilter == value;
    final isMobile = ResponsiveUtils.isMobile(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _currentPage = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: AppTheme.md,
          horizontal: isMobile ? AppTheme.lg : AppTheme.md,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.white : AppTheme.mediumGrey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? AppTheme.white : AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
  Widget _buildReservationsTable() {
    if (_isLoading) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5 * value,
                        )
                      ]
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LOADING RESERVATIONS...',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      );
    }

    final filtered = _filteredReservations;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < filtered.length) 
        ? startIndex + _rowsPerPage 
        : filtered.length;
    final paginatedReservations = filtered.sublist(startIndex, endIndex);
    
    return Card(
      elevation: isMobile ? 1 : 2,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: DataTable(
                      columnSpacing: 8,
                      horizontalMargin: 8,
                      headingRowHeight: 44,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 52,
                      dividerThickness: 0.5,
                      headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withOpacity(0.04)),
                      headingTextStyle: TextStyle(
                        color: AppTheme.darkGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 10, tablet: 11, desktop: 12),
                        letterSpacing: 0.3,
                      ),
                      columns: [
                        DataColumn(label: _buildColumnHeader('Customer', Icons.person_outline, isMobile)),
                        DataColumn(label: _buildColumnHeader('Event', Icons.celebration_outlined, isMobile)),
                        DataColumn(label: _buildColumnHeader('Date', Icons.calendar_today_outlined, isMobile)),
                        DataColumn(label: _buildColumnHeader('Time', Icons.access_time, isMobile)),
                        DataColumn(label: _buildColumnHeader('Guests', Icons.people_outline, isMobile)),
                        DataColumn(label: _buildColumnHeader('Status', Icons.check_circle_outline, isMobile)),
                        DataColumn(label: _buildColumnHeader('Actions', Icons.settings_outlined, isMobile)),
                      ],
                      rows: paginatedReservations.map((reservation) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: isMobile ? 80 : 120,
                                child: Text(
                                  isMobile
                                      ? (reservation['customer_name']?.toString().split(' ')[0] ?? '')
                                      : reservation['customer_name'] ?? '',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                                      context,
                                      mobile: 10,
                                      tablet: 11,
                                      desktop: 12,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 80,
                                child: Text(
                                  reservation['event_type'] ?? '',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                                      context,
                                      mobile: 10,
                                      tablet: 11,
                                      desktop: 12,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: _buildCompactDateBadge(reservation['event_date']?.toString() ?? ''),
                              ),
                            ),
                            DataCell(
                              _buildCompactTimeBadge(reservation['start_time']?.toString() ?? ''),
                            ),
                            DataCell(
                              Text(
                                '${reservation['number_of_guests']}',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: 10,
                                    tablet: 11,
                                    desktop: 12,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(_buildCompactStatusChip(reservation['status'])),
                            DataCell(_buildCompactActionButtons(reservation)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
          if (filtered.length > _rowsPerPage)
            _buildPaginationControls(filtered.length),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalItems) 
        ? startIndex + _rowsPerPage 
        : totalItems;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${startIndex + 1}-$endIndex of $totalItems',
            style: const TextStyle(fontSize: 13, color: AppTheme.darkGrey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 
                ? () => setState(() => _currentPage--) 
                : null,
            splashRadius: 20,
            color: AppTheme.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: endIndex < totalItems 
                ? () => setState(() => _currentPage++) 
                : null,
            splashRadius: 20,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList() {
    if (_isLoading) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5 * value,
                        )
                      ]
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LOADING RESERVATIONS...',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      );
    }

    if (_filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      itemCount: _filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = _filteredReservations[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey(reservation['id']),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 600)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 8 : 16),
            child: _HoverAnimatedCard(
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: Row(
              children: [
                // Compact Date/Time Stub
                Container(
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusLg),
                      bottomLeft: Radius.circular(AppTheme.radiusLg),
                    ),
                    border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.15), style: BorderStyle.solid)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCompactDateBadge(reservation['event_date']?.toString() ?? ''),
                        const SizedBox(height: 6),
                        _buildCompactTimeBadge(reservation['start_time']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ),
                
                // Compact Main Body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 10.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reservation['event_type'] ?? '',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: 13,
                                    tablet: 15,
                                    desktop: 17,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildCompactStatusChip(reservation['status']),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Customer & Guest Info Row
                        Row(
                          children: [
                            Icon(Icons.person, size: 12, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reservation['customer_name'] ?? '',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                  color: AppTheme.darkGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.group, size: 12, color: AppTheme.mediumGrey),
                            const SizedBox(width: 4),
                            Text(
                              '${reservation['number_of_guests']}',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reservation['customer_email'] ?? '',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 9, tablet: 10, desktop: 11),
                                  color: AppTheme.mediumGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildCompactActionButtons(reservation),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
        padding: const EdgeInsets.all(AppTheme.xl),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded, 
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 48, tablet: 56, desktop: 64), 
                color: AppTheme.primaryColor,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 28, desktop: 32),
            Text(
              'No Events Found',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'There are no reservations matching the currently selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
                color: AppTheme.mediumGrey,
                height: 1.5,
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 24, tablet: 28, desktop: 32),
            if (_selectedFilter != 'all')
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'all';
                  });
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl, vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
              ),
          ],
        ),
       ),
      ),
    );
  }

  void _showConfirmReservationDialog(Map<String, dynamic> reservation) {
    String reservationId = reservation['id'];
    String eventType = reservation['event_type'];
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              Icons.check_circle, 
              color: Colors.green,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Confirm Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to confirm "$eventType" reservation?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              'This will notify the customer that their reservation has been confirmed.',
              style: TextStyle(
                color: Colors.green,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(reservationId, 'confirmed', reservation);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String reservationId, String eventType, {bool isArchived = false}) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
        title: Row(
          children: [
            Icon(
              isArchived ? Icons.delete_forever : Icons.archive, 
              color: isArchived ? Colors.red : Colors.orange,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                isArchived ? 'Permanent Delete' : 'Archive Reservation',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArchived 
                ? 'Are you sure you want to permanently delete "$eventType"?' 
                : 'Move "$eventType" reservation to archive?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 10, desktop: 12),
            Text(
              isArchived 
                ? 'This action CANNOT be undone. All data will be lost.' 
                : 'It will be removed from your active list but can be recovered from the Archive section.',
              style: TextStyle(
                color: isArchived ? Colors.red : AppTheme.mediumGrey,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 13,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isArchived ? Colors.red : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 8 : 12,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (isArchived) {
                _hardDeleteReservation(reservationId);
              } else {
                _archiveReservation(reservationId);
              }
            },
            child: Text(
              isArchived ? 'Delete Permanently' : 'Archive',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCompactDateBadge(String dateString) {
    if (dateString.isEmpty) return const Text('N/A');
    try {
      final date = DateTime.parse(dateString);
      final month = DateFormat('MMM').format(date).toUpperCase();
      final day = DateFormat('dd').format(date);
      
      return Container(
        width: 42,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
              child: Text(
                month,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 1),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.darkGrey,
                  fontSize: 14,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Text(dateString, style: const TextStyle(fontSize: 10));
    }
  }

  Widget _buildCompactTimeBadge(String timeString) {
    if (timeString.isEmpty) return const Text('N/A');
    String displayTime = timeString;
    try {
      if (!timeString.toUpperCase().contains('M')) {
        String formatted = timeString;
        if (formatted.length >= 5) formatted = formatted.substring(0, 5); 
        final parts = formatted.split(':');
        if (parts.length == 2) {
          final dt = DateTime(2020, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
          displayTime = DateFormat.jm().format(dt);
        }
      }
    } catch (e) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, size: 10, color: AppTheme.primaryColor),
          const SizedBox(width: 3),
          Text(
            displayTime,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String title, IconData icon, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: AppTheme.primaryColor.withOpacity(0.7)),
        SizedBox(width: isMobile ? 4 : 8),
        Flexible(
          child: Text(
            title.toUpperCase(), 
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.done_all;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButtons(Map<String, dynamic> reservation) {
    String status = reservation['status'] ?? 'pending';
    String reservationId = reservation['id'];
    bool isArchived = reservation['is_archived'] == true;
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isArchived) ...[
          if (status == 'pending') ...[
            if (needsPricing || status == 'pending')
              _buildCompactActionButton(
                icon: Icons.monetization_on_outlined,
                color: Colors.purple,
                tooltip: 'Price',
                onPressed: () => _showPriceQuotationDialog(reservation),
              ),
            if (priceQuotationSent)
              _buildCompactActionButton(
                icon: Icons.check_circle_outline,
                color: AppTheme.successGreen,
                tooltip: 'Confirm',
                onPressed: () => _showConfirmReservationDialog(reservation),
              ),
            _buildCompactActionButton(
              icon: Icons.close_rounded,
              color: Colors.red,
              tooltip: 'Cancel',
              onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
            ),
          ],
          if (status == 'confirmed') ...[
            _buildCompactActionButton(
              icon: Icons.cancel_outlined,
              color: Colors.red,
              tooltip: 'Cancel',
              onPressed: () => _updateReservationStatus(reservationId, 'cancelled', reservation),
            ),
          ],
        ],
        _buildCompactActionButton(
          icon: Icons.visibility_outlined,
          color: AppTheme.infoBlue,
          tooltip: 'View',
          onPressed: () => _showViewReservationDialog(reservation),
        ),
        if (isArchived)
          _buildCompactActionButton(
            icon: Icons.restore_rounded,
            color: AppTheme.successGreen,
            tooltip: 'Restore',
            onPressed: () => _restoreReservation(reservationId),
          ),
        if (isArchived || status == 'cancelled' || status == 'completed')
          _buildCompactActionButton(
            icon: isArchived ? Icons.delete_outline_rounded : Icons.archive_outlined,
            color: isArchived ? Colors.red : Colors.orange,
            tooltip: isArchived ? 'Delete' : 'Archive',
            onPressed: () => _showDeleteConfirmationDialog(reservationId, reservation['event_type'], isArchived: isArchived),
          ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            hoverColor: color.withOpacity(0.12),
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.15), width: 1),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      ),
    );
  }

  void _showPriceQuotationDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PriceQuotationDialog(reservation: reservation),
    ).then((result) {
      if (result == true) {
        _loadReservations(); // Refresh the list after sending quotation
      }
    });
  }

  void _showViewReservationDialog(Map<String, dynamic> reservation) {
    final status = reservation['status'];
    final isPending = status == 'pending';
    final isMobile = ResponsiveUtils.isMobile(context);
    final needsPricing = _reservationService.needsPricing(reservation);
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

    Widget buildDetailRow(String label, String value, {IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppTheme.darkGrey),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Reservation Details'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: isMobile ? double.maxFinite : 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      buildDetailRow('Customer Name', reservation['customer_name'] ?? 'N/A', icon: Icons.person),
                      buildDetailRow('Email', reservation['customer_email'] ?? 'N/A', icon: Icons.email),
                      buildDetailRow('Phone', reservation['customer_phone'] ?? 'N/A', icon: Icons.phone),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                buildDetailRow('Event Type', reservation['event_type'] ?? 'N/A', icon: Icons.event),
                buildDetailRow('Event Date', reservation['event_date'] ?? 'N/A', icon: Icons.calendar_today),
                buildDetailRow('Start Time', reservation['start_time'] ?? 'N/A', icon: Icons.access_time),
                buildDetailRow('Guests', '${reservation['number_of_guests'] ?? '0'}', icon: Icons.people),
                buildDetailRow('Table Number', reservation['table_number']?.toString() ?? 'Unassigned', icon: Icons.table_restaurant),
                const SizedBox(height: 16),
                buildDetailRow('Status', status?.toString().toUpperCase() ?? 'UNKNOWN', icon: Icons.info),
                
                // Pricing information
                if (reservation['total_price'] != null && reservation['total_price'] > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  buildDetailRow('Total Price', 'PHP ${(reservation['total_price'] as double).toStringAsFixed(2)}', icon: Icons.monetization_on),
                  buildDetailRow('Deposit Required', 'PHP ${(reservation['deposit_amount'] as double).toStringAsFixed(2)}', icon: Icons.account_balance_wallet),
                  buildDetailRow('Payment Status', (reservation['payment_status'] as String? ?? 'unpaid').toUpperCase(), icon: Icons.payment),
                  buildDetailRow('Transaction Sent', reservation['price_quotation_sent'] == true ? 'Yes' : 'No', icon: Icons.email),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isPending && needsPricing)
            ElevatedButton.icon(
              icon: const Icon(Icons.monetization_on, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showPriceQuotationDialog(reservation);
              },
              label: const Text('Set Price'),
            ),
          if (isPending && priceQuotationSent)
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _updateReservationStatus(reservation['id'], 'confirmed', reservation);
              },
              label: const Text('Accept Reservation'),
            ),
        ],
      ),
    );
  }
}

class _HoverAnimatedCard extends StatefulWidget {
  final Widget child;

  const _HoverAnimatedCard({required this.child});

  @override
  State<_HoverAnimatedCard> createState() => _HoverAnimatedCardState();
}

class _HoverAnimatedCardState extends State<_HoverAnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_isHovered ? 1.01 : 1.0)
          ..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
